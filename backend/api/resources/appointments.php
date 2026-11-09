<?php
// Viewing requests. docs/api.md §3.7
// pending -> confirmed | declined (owner), pending | confirmed -> cancelled (viewer)

function appointment_statuses()
{
    return ['pending', 'confirmed', 'declined', 'cancelled'];
}

const APPOINTMENT_SELECT = "
    a.appointment_id, a.status, a.message, a.created_at, a.updated_at,
    s.viewing_date, s.viewing_time,
    p.property_id, p.title, p.address, p.city,
    (SELECT i.file_path FROM property_images i
      WHERE i.property_id = p.property_id AND i.is_hidden = 0
      ORDER BY i.sort_order, i.image_id LIMIT 1) AS cover_image,
    v.user_id AS viewer_id, v.full_name AS viewer_name,
    o.user_id AS owner_id, o.full_name AS owner_name, o.phone AS owner_phone
";
const APPOINTMENT_FROM = '
    FROM appointments a
    JOIN availability_slots s ON s.slot_id = a.slot_id
    JOIN properties p ON p.property_id = a.property_id
    JOIN users v ON v.user_id = a.viewer_id
    JOIN users o ON o.user_id = p.owner_id
';

// POST /appointments {slot_id, property_id, message?} - book a free day
function appointments_create()
{
    $user = require_user();
    $in = body();
    $v = new Validator($in);
    $v->number('slot_id', 1, PHP_INT_MAX, true, 'Pick a viewing day', true)
      ->number('property_id', 1, PHP_INT_MAX, true, 'Choose a listing', true)
      ->text('message', 0, 500, false, 'Keep the message under 500 characters');
    $v->done();
    $slotId = (int) $in['slot_id'];
    $propertyId = (int) $in['property_id'];
    $message = $v->value('message');

    // Check the request makes sense before taking the day
    $stmt = db()->prepare(
        'SELECT p.owner_id, p.status, s.is_booked,
                TIMESTAMP(s.viewing_date, s.viewing_time) > NOW() AS is_future
         FROM availability_slots s
         JOIN properties p ON p.owner_id = s.owner_id
         WHERE s.slot_id = ? AND p.property_id = ?'
    );
    $stmt->execute([$slotId, $propertyId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        fail(422, 'Validation failed', ['slot_id' => "That day isn't offered for this listing"]);
    }
    if ((int) $row['owner_id'] === $user['user_id']) {
        fail(422, 'Validation failed', ['property_id' => "You can't book a viewing of your own listing"]);
    }
    if ($row['status'] !== 'available') {
        fail(422, 'Validation failed', ['property_id' => 'This listing is no longer available']);
    }
    if (!$row['is_future']) {
        fail(422, 'Validation failed', ['slot_id' => 'That day has already passed']);
    }
    $open = db()->prepare(
        "SELECT 1 FROM appointments
         WHERE viewer_id = ? AND property_id = ? AND status IN ('pending', 'confirmed')"
    );
    $open->execute([$user['user_id'], $propertyId]);
    if ($open->fetchColumn()) {
        fail(409, 'You already have a viewing booked for this home');
    }

    db()->beginTransaction();
    // Only one booking can flip is_booked 0 -> 1, so two people never get the same day
    $take = db()->prepare('UPDATE availability_slots SET is_booked = 1 WHERE slot_id = ? AND is_booked = 0');
    $take->execute([$slotId]);
    if ($take->rowCount() === 0) {
        db()->rollBack();
        fail(409, 'Sorry, this day was just booked');
    }
    db()->prepare('INSERT INTO appointments (slot_id, property_id, viewer_id, message) VALUES (?, ?, ?, ?)')
        ->execute([$slotId, $propertyId, $user['user_id'], $message === '' ? null : $message]);
    $id = (int) db()->lastInsertId();
    db()->commit();

    json_out(appointment_by_id($id), 201);
}

// GET /me/appointments?as=viewer&when=upcoming|past
// GET /me/appointments?as=owner&status=pending
function appointments_index()
{
    $user = require_user();
    $as = pick($_GET, 'as', 'viewer');
    if (!in_array($as, ['viewer', 'owner'], true)) {
        fail(422, 'Validation failed', ['as' => 'Use as=viewer or as=owner']);
    }
    if ($as === 'owner') {
        require_owner();
    }
    list($limit, $offset, $page, $perPage) = paging();

    $where = $as === 'owner' ? ['p.owner_id = :me'] : ['a.viewer_id = :me'];
    $params = ['me' => $user['user_id']];
    $upcoming = "a.status IN ('pending', 'confirmed') AND TIMESTAMP(s.viewing_date, s.viewing_time) > NOW()";
    $order = 's.viewing_date, s.viewing_time, a.appointment_id';

    $status = pick($_GET, 'status', '');
    if ($status !== '') {
        if (!in_array($status, appointment_statuses(), true)) {
            fail(422, 'Validation failed', ['status' => 'Unknown status']);
        }
        $where[] = 'a.status = :status';
        $params['status'] = $status;
    }
    $when = pick($_GET, 'when', '');
    if ($when === 'upcoming') {
        $where[] = $upcoming;
    } elseif ($when === 'past') {
        $where[] = "NOT ($upcoming)";
        $order = 's.viewing_date DESC, s.viewing_time DESC, a.appointment_id DESC';
    } elseif ($as === 'viewer') {
        $order = 'a.created_at DESC, a.appointment_id DESC'; // newest booking first
    }
    $whereSql = implode(' AND ', $where);

    $count = db()->prepare('SELECT COUNT(*) ' . APPOINTMENT_FROM . " WHERE $whereSql");
    $count->execute($params);
    $total = (int) $count->fetchColumn();

    // LIMIT values are ints from paging(), safe to inline
    $stmt = db()->prepare(
        'SELECT ' . APPOINTMENT_SELECT . APPOINTMENT_FROM . " WHERE $whereSql ORDER BY $order LIMIT $limit OFFSET $offset"
    );
    $stmt->execute($params);
    $meta = page_meta($total, $page, $perPage);

    // Owner tabs show a count per status
    if ($as === 'owner') {
        $counts = db()->prepare(
            'SELECT a.status, COUNT(*) ' . APPOINTMENT_FROM . ' WHERE p.owner_id = ? GROUP BY a.status'
        );
        $counts->execute([$user['user_id']]);
        $meta['counts'] = array_merge(
            array_fill_keys(appointment_statuses(), 0),
            array_map('intval', $counts->fetchAll(PDO::FETCH_KEY_PAIR))
        );
    }
    json_out(array_map('appointment_row', $stmt->fetchAll(PDO::FETCH_ASSOC)), 200, $meta);
}

// PATCH /appointments/:id {status}
function appointments_update($id)
{
    $user = require_user();
    $in = body();
    $status = pick($in, 'status', '');
    if (!in_array($status, ['confirmed', 'declined', 'cancelled'], true)) {
        fail(422, 'Validation failed', ['status' => 'Use confirmed, declined or cancelled']);
    }

    $stmt = db()->prepare(
        'SELECT a.status, a.viewer_id, s.owner_id, s.slot_id,
                TIMESTAMP(s.viewing_date, s.viewing_time) > NOW() AS is_future
         FROM appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
         WHERE a.appointment_id = ?'
    );
    $stmt->execute([$id]);
    $a = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$a) {
        fail(404, 'Viewing not found');
    }

    // Who may set which status, and from which status (docs/api.md §3.7)
    $isOwner = (int) $a['owner_id'] === $user['user_id'];
    $isViewer = (int) $a['viewer_id'] === $user['user_id'];
    $rules = [
        'confirmed' => [$isOwner, ['pending']],
        'declined'  => [$isOwner, ['pending']],
        'cancelled' => [$isViewer, ['pending', 'confirmed']],
    ];
    list($allowed, $from) = $rules[$status];
    if (!$allowed) {
        fail(403, $status === 'cancelled'
            ? 'Only the person who booked can cancel'
            : 'Only the owner can confirm or decline');
    }
    if (!in_array($a['status'], $from, true)) {
        fail(409, "This viewing is already {$a['status']}");
    }
    if (!$a['is_future']) {
        fail(409, 'This viewing date has already passed');
    }

    // Status and (for declined/cancelled) the freed day in ONE statement;
    // the status in WHERE stops two clicks racing each other
    $freeDay = $status === 'confirmed' ? '' : ', s.is_booked = 0';
    $update = db()->prepare(
        "UPDATE appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
         SET a.status = ?, a.updated_at = NOW() $freeDay
         WHERE a.appointment_id = ? AND a.status = ?"
    );
    $update->execute([$status, $id, $a['status']]);
    if ($update->rowCount() === 0) {
        fail(409, 'This viewing changed just now, please reload');
    }
    json_out(appointment_by_id($id));
}

function appointment_by_id($id)
{
    $stmt = db()->prepare('SELECT ' . APPOINTMENT_SELECT . APPOINTMENT_FROM . ' WHERE a.appointment_id = ?');
    $stmt->execute([$id]);
    return appointment_row($stmt->fetch(PDO::FETCH_ASSOC));
}

function appointment_row(array $r)
{
    return [
        'appointment_id' => (int) $r['appointment_id'],
        'status'         => $r['status'],
        'message'        => $r['message'],
        'viewing_date'   => $r['viewing_date'],
        'viewing_time'   => substr($r['viewing_time'], 0, 5),
        'property'       => [
            'property_id' => (int) $r['property_id'],
            'title'       => $r['title'],
            'address'     => $r['address'],
            'city'        => $r['city'],
            'cover_image' => $r['cover_image'],
        ],
        'viewer'         => ['user_id' => (int) $r['viewer_id'], 'full_name' => $r['viewer_name']],
        'owner'          => [
            'user_id'   => (int) $r['owner_id'],
            'full_name' => $r['owner_name'],
            'phone'     => $r['owner_phone'],
        ],
        'created_at'     => $r['created_at'],
        'updated_at'     => $r['updated_at'],
    ];
}
