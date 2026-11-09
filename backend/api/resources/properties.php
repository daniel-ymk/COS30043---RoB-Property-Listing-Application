<?php
// Property listings. docs/api.md §3.2

function listing_types()
{
    return ['rent', 'sale'];
}

function property_types()
{
    return ['apartment', 'condo', 'house', 'townhouse', 'studio', 'room'];
}

function sorts()
{
    return [
        'newest'     => 'p.created_at DESC, p.property_id DESC',
        'price_asc'  => 'p.price ASC, p.property_id DESC',
        'price_desc' => 'p.price DESC, p.property_id DESC',
        'most_liked' => 'like_count DESC, p.created_at DESC',
    ];
}

// GET /properties?<filters>  - public search (available listings only)
// GET /properties?ids=1,3,5  - compare page, up to 4, any status
function properties_index()
{
    if (isset($_GET['ids'])) {
        properties_compare((string) $_GET['ids']);
    }

    $where = ["p.status = 'available'"];
    $params = ['me' => current_user_id()];

    $q = trim((string) (pick($_GET, 'q', '')));
    if ($q !== '') {
        $where[] = '(p.title LIKE :q1 OR p.address LIKE :q2 OR p.city LIKE :q3)';
        $like = '%' . addcslashes($q, '%_\\') . '%';
        $params += ['q1' => $like, 'q2' => $like, 'q3' => $like];
    }
    if (in_array(pick($_GET, 'listing_type', ''), listing_types(), true)) {
        $where[] = 'p.listing_type = :listing_type';
        $params['listing_type'] = $_GET['listing_type'];
    }
    // property_type=condo or property_type=condo,house (any of them)
    $types = array_values(array_intersect(
        property_types(),
        explode(',', (string) (pick($_GET, 'property_type', '')))
    ));
    if ($types) {
        $names = [];
        foreach ($types as $i => $type) {
            $names[] = ":type$i";
            $params["type$i"] = $type;
        }
        $where[] = 'p.property_type IN (' . implode(', ', $names) . ')';
    }
    if ((pick($_GET, 'city', '')) !== '') {
        $where[] = 'p.city = :city';
        $params['city'] = (string) $_GET['city'];
    }
    if (is_numeric(pick($_GET, 'min_price'))) {
        $where[] = 'p.price >= :min_price';
        $params['min_price'] = (float) $_GET['min_price'];
    }
    if (is_numeric(pick($_GET, 'max_price'))) {
        $where[] = 'p.price <= :max_price';
        $params['max_price'] = (float) $_GET['max_price'];
    }
    if (is_numeric(pick($_GET, 'min_bedrooms'))) {
        $where[] = 'p.bedrooms >= :min_bedrooms';
        $params['min_bedrooms'] = (int) $_GET['min_bedrooms'];
    }
    if ((pick($_GET, 'furnished', '')) === '1') {
        $where[] = 'p.is_furnished = 1';
    }

    $sorts = sorts();
    $sort = pick($_GET, 'sort', 'newest');
    $order = isset($sorts[$sort]) ? $sorts[$sort] : $sorts['newest'];
    list_cards(implode(' AND ', $where), $params, $order);
}

// GET /me/properties - the owner's own listings, every status
function properties_mine()
{
    $user = require_owner();
    list_cards('p.owner_id = :owner', ['me' => $user['user_id'], 'owner' => $user['user_id']], sorts()['newest']);
}

// GET /properties/:id
function properties_show($id)
{
    $detail = property_detail($id);
    if (!$detail) {
        fail(404, 'Listing not found');
    }
    json_out($detail);
}

// Paged list of cards for a WHERE clause; sends { data, meta }.
function list_cards($where, array $params, $order)
{
    list($limit, $offset, $page, $perPage) = paging();

    $count = db()->prepare("SELECT COUNT(*) FROM properties p WHERE $where");
    $count->execute(array_diff_key($params, ['me' => 0]));
    $total = (int) $count->fetchColumn();

    // LIMIT values are ints from paging(), safe to inline
    $stmt = db()->prepare(
        'SELECT ' . CARD_SELECT . " FROM properties p WHERE $where ORDER BY $order LIMIT $limit OFFSET $offset"
    );
    $stmt->execute($params);
    json_out(array_map('card_row', $stmt->fetchAll(PDO::FETCH_ASSOC)), 200, page_meta($total, $page, $perPage));
}

function properties_compare($ids)
{
    $ids = array_slice(array_unique(array_filter(array_map('intval', explode(',', $ids)))), 0, 4);
    $out = [];
    foreach ($ids as $id) {
        $detail = property_detail($id);
        if ($detail) {
            $out[] = $detail;
        }
    }
    json_out($out);
}

function listing_statuses()
{
    return ['available', 'rented', 'sold'];
}

// Messages shared with frontend/src/utils/validation.js (docs/api.md §4)
function listing_messages()
{
    return [
        'title'          => 'Title must be 5–150 characters',
        'description'    => 'Description must be 20–5000 characters',
        'listing_type'   => 'Choose rent or sale',
        'property_type'  => 'Choose a property type',
        'status'         => 'Choose available, rented or sold',
        'price'          => 'Enter a price above 0',
        'rooms'          => 'Enter a whole number from 0 to 20',
        'floor_area_sqm' => 'Floor area must be 5–100,000 m²',
        'address'        => 'Enter the street address',
        'city'           => 'Enter the city',
        'state'          => 'State must be 100 characters or fewer',
        'postcode'       => 'Postcode must be 4–10 digits',
        'location'       => 'Place the pin on the map again',
    ];
}

// POST /properties - new listing (always starts as available)
function properties_create()
{
    $user = require_owner();
    $data = listing_input(body(), false);

    $columns = array_keys($data);
    $stmt = db()->prepare(
        'INSERT INTO properties (owner_id, ' . implode(', ', $columns) . ')
         VALUES (?' . str_repeat(', ?', count($columns)) . ')'
    );
    $stmt->execute(array_merge([$user['user_id']], array_values($data)));
    json_out(property_detail((int) db()->lastInsertId()), 201);
}

// PUT /properties/:id - replace every field (same rules as POST, plus status)
function properties_update($id)
{
    $old = require_own_property($id);
    $data = listing_input(body(), true);

    // Column names come from listing_input(), never from the request
    $sets = implode(', ', array_map(function ($column) {
        return "$column = ?";
    }, array_keys($data)));
    db()->beginTransaction();
    db()->prepare("UPDATE properties SET $sets, updated_at = NOW() WHERE property_id = ?")
        ->execute(array_merge(array_values($data), [$id]));
    close_viewings_if_taken($old, $data['status']);
    db()->commit();
    json_out(property_detail($id));
}

// PATCH /properties/:id {status} - change only the status (My listings menu)
function properties_set_status($id)
{
    $old = require_own_property($id);
    $in = body();
    $v = new Validator($in);
    $v->oneOf('status', listing_statuses(), listing_messages()['status']);
    $v->check(array_keys($in) === ['status'], 'status', 'Only status can be changed here; use PUT for the rest');
    $v->done();

    db()->beginTransaction();
    db()->prepare('UPDATE properties SET status = ?, updated_at = NOW() WHERE property_id = ?')
        ->execute([$in['status'], $id]);
    close_viewings_if_taken($old, $in['status']);
    db()->commit();
    json_out(property_detail($id));
}

// DELETE /properties/:id - listing, photos (rows and files), likes, viewings
function properties_destroy($id)
{
    require_own_property($id);

    db()->beginTransaction();
    // Days held by its open viewings become free again
    db()->prepare(
        "UPDATE availability_slots s
         JOIN appointments a ON a.slot_id = s.slot_id
         SET s.is_booked = 0
         WHERE a.property_id = ? AND a.status IN ('pending', 'confirmed')"
    )->execute([$id]);
    // images, likes and appointments go with it (ON DELETE CASCADE)
    db()->prepare('DELETE FROM properties WHERE property_id = ?')->execute([$id]);
    db()->commit();

    remove_upload_dir($id);
    json_out(null, 204);
}

// Rented or sold: open requests are declined, confirmed viewings cancelled,
// and their days freed (schema.sql reference SQL).
function close_viewings_if_taken(array $old, $newStatus)
{
    if ($newStatus === 'available' || $old['status'] === $newStatus) {
        return;
    }
    db()->prepare(
        "UPDATE appointments a JOIN availability_slots s ON s.slot_id = a.slot_id
         SET a.status = IF(a.status = 'pending', 'declined', 'cancelled'),
             a.updated_at = NOW(), s.is_booked = 0
         WHERE a.property_id = ? AND a.status IN ('pending', 'confirmed')"
    )->execute([$old['property_id']]);
}

// Validates a create/replace body and returns column => value.
function listing_input(array $in, $withStatus)
{
    $m = listing_messages();
    $v = new Validator($in);
    $v->text('title', 5, 150, true, $m['title'])
      ->text('description', 20, 5000, true, $m['description'])
      ->oneOf('listing_type', listing_types(), $m['listing_type'])
      ->oneOf('property_type', property_types(), $m['property_type'])
      ->number('price', 0.01, 9999999999, true, $m['price'])
      ->number('bedrooms', 0, 20, true, $m['rooms'], true)
      ->number('bathrooms', 0, 20, true, $m['rooms'], true)
      ->number('parking_spaces', 0, 20, true, $m['rooms'], true)
      ->number('floor_area_sqm', 5, 100000, false, $m['floor_area_sqm'])
      ->text('address', 1, 255, true, $m['address'])
      ->text('city', 1, 100, true, $m['city'])
      ->text('state', 1, 100, false, $m['state'])
      ->digits('postcode', 4, 10, false, $m['postcode'])
      ->number('latitude', -90, 90, false, $m['location'])
      ->number('longitude', -180, 180, false, $m['location']);
    $v->check(is_bool(pick($in, 'is_furnished', false)), 'is_furnished', 'Choose furnished or not');
    // Both coordinates or neither
    $hasLat = !in_array(pick($in, 'latitude'), [null, ''], true);
    $hasLng = !in_array(pick($in, 'longitude'), [null, ''], true);
    $v->check($hasLat === $hasLng, 'latitude', $m['location']);
    if ($withStatus) {
        $v->oneOf('status', listing_statuses(), $m['status']);
    }
    $v->done();

    $optional = function ($field) use ($v) {
        $value = $v->value($field);
        return $value === null || $value === '' ? null : $value;
    };
    $data = [
        'title'          => $v->value('title'),
        'description'    => $v->value('description'),
        'listing_type'   => $v->value('listing_type'),
        'property_type'  => $v->value('property_type'),
        'price'          => (float) $v->value('price'),
        'bedrooms'       => (int) $v->value('bedrooms'),
        'bathrooms'      => (int) $v->value('bathrooms'),
        'parking_spaces' => (int) $v->value('parking_spaces'),
        'floor_area_sqm' => $optional('floor_area_sqm'),
        'is_furnished'   => !empty($in['is_furnished']) ? 1 : 0,
        'address'        => $v->value('address'),
        'city'           => $v->value('city'),
        'state'          => $optional('state'),
        'postcode'       => $optional('postcode'),
        'latitude'       => $hasLat ? (float) $in['latitude'] : null,
        'longitude'      => $hasLng ? (float) $in['longitude'] : null,
    ];
    if ($withStatus) {
        $data['status'] = $v->value('status');
    }
    return $data;
}
