<?php
// Owners' viewing days (one per owner per day). docs/api.md §3.6

function slot_messages()
{
    return [
    'viewing_date' => 'Pick today or a later date',
    'viewing_time' => 'Pick a time between 8:00 AM and 8:00 PM',
    'past_time'    => 'That time has already passed today',
];
}

// GET /properties/:id/slots - free, future days of the listing's owner
// (none when the listing is not available)
function slots_for_property($propertyId)
{
    $exists = db()->prepare('SELECT 1 FROM properties WHERE property_id = ?');
    $exists->execute([$propertyId]);
    if (!$exists->fetchColumn()) {
        fail(404, 'Listing not found');
    }
    $stmt = db()->prepare(
        "SELECT s.slot_id, s.viewing_date, s.viewing_time
         FROM availability_slots s
         JOIN properties p ON p.owner_id = s.owner_id
         WHERE p.property_id = ?
           AND p.status = 'available'
           AND s.is_booked = 0
           AND TIMESTAMP(s.viewing_date, s.viewing_time) > NOW()
         ORDER BY s.viewing_date"
    );
    $stmt->execute([$propertyId]);
    json_out(array_map('slot_row', $stmt->fetchAll(PDO::FETCH_ASSOC)));
}

// GET /me/slots - my days from today on; booked days carry the
// appointment that holds them, so the calendar can link to the request
function slots_mine()
{
    $user = require_owner();
    $stmt = db()->prepare(
        "SELECT s.slot_id, s.viewing_date, s.viewing_time, s.is_booked,
                (SELECT a.appointment_id FROM appointments a
                  WHERE a.slot_id = s.slot_id AND a.status IN ('pending', 'confirmed')
                  ORDER BY a.appointment_id DESC LIMIT 1) AS appointment_id
         FROM availability_slots s
         WHERE s.owner_id = ? AND s.viewing_date >= CURDATE()
         ORDER BY s.viewing_date"
    );
    $stmt->execute([$user['user_id']]);
    json_out(array_map('slot_row', $stmt->fetchAll(PDO::FETCH_ASSOC)));
}

// POST /me/slots {viewing_date, viewing_time}
function slots_create()
{
    $user = require_owner();
    $in = body();
    $date = trim((string) (pick($in, 'viewing_date', '')));
    $time = trim((string) (pick($in, 'viewing_time', '')));

    $v = new Validator($in);
    $parsed = DateTime::createFromFormat('!Y-m-d', $date);
    $validDate = $parsed && $parsed->format('Y-m-d') === $date;
    $v->check($validDate && $date >= date('Y-m-d'), 'viewing_date', slot_messages()['viewing_date']);
    $validTime = (bool) preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $time);
    $v->check($validTime && $time >= '08:00' && $time <= '20:00', 'viewing_time', slot_messages()['viewing_time']);
    if ($validDate && $validTime && $date === date('Y-m-d')) {
        $v->check($time > date('H:i'), 'viewing_time', slot_messages()['past_time']);
    }
    $v->done();

    try {
        db()->prepare('INSERT INTO availability_slots (owner_id, viewing_date, viewing_time) VALUES (?, ?, ?)')
            ->execute([$user['user_id'], $date, "$time:00"]);
    } catch (PDOException $e) {
        // UNIQUE (owner_id, viewing_date): one viewing per day
        if ($e->getCode() === '23000') {
            fail(409, 'You already have a viewing on this day');
        }
        throw $e;
    }
    json_out(slot_row([
        'slot_id'        => db()->lastInsertId(),
        'viewing_date'   => $date,
        'viewing_time'   => $time,
        'is_booked'      => 0,
        'appointment_id' => null,
    ]), 201);
}

// DELETE /me/slots/:id - only free days
function slots_destroy($slotId)
{
    $user = require_owner();
    $stmt = db()->prepare('SELECT owner_id, is_booked FROM availability_slots WHERE slot_id = ?');
    $stmt->execute([$slotId]);
    $slot = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$slot) {
        fail(404, 'Viewing day not found');
    }
    if ((int) $slot['owner_id'] !== $user['user_id']) {
        fail(403, 'This is not your viewing day');
    }
    if ((int) $slot['is_booked'] === 1) {
        fail(409, 'This day is booked. Decline or cancel the viewing first.');
    }
    // Old declined/cancelled requests on this day go with it (ON DELETE CASCADE)
    db()->prepare('DELETE FROM availability_slots WHERE slot_id = ? AND is_booked = 0')->execute([$slotId]);
    json_out(null, 204);
}

function slot_row(array $r)
{
    $row = [
        'slot_id'      => (int) $r['slot_id'],
        'viewing_date' => $r['viewing_date'],
        'viewing_time' => substr($r['viewing_time'], 0, 5), // "14:00"
    ];
    if (array_key_exists('is_booked', $r)) {
        $row['is_booked'] = (bool) $r['is_booked'];
        $row['appointment_id'] = $r['appointment_id'] === null ? null : (int) $r['appointment_id'];
    }
    return $row;
}
