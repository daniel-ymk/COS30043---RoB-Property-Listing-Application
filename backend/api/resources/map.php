<?php
// Map search and the city list. docs/api.md §3.3

const MAP_LIMIT = 200;

// GET /map?north=&south=&east=&west= - available listings inside the visible map
function map_index()
{
    $box = [];
    foreach (['north' => 90, 'south' => 90, 'east' => 180, 'west' => 180] as $side => $max) {
        $value = pick($_GET, $side);
        if (!is_numeric($value) || abs((float) $value) > $max) {
            fail(422, 'Validation failed', [$side => 'Send the map bounds as numbers']);
        }
        $box[$side] = (float) $value;
    }
    if ($box['south'] > $box['north']) {
        fail(422, 'Validation failed', ['south' => 'south must be below north']);
    }

    // LIMIT is a constant int, safe to inline
    $stmt = db()->prepare(
        'SELECT ' . CARD_SELECT . "
         FROM properties p
         WHERE p.status = 'available'
           AND p.latitude BETWEEN :south AND :north
           AND p.longitude BETWEEN :west AND :east
         ORDER BY p.created_at DESC
         LIMIT " . MAP_LIMIT
    );
    $stmt->execute(['me' => current_user_id()] + $box);
    json_out(array_map('card_row', $stmt->fetchAll(PDO::FETCH_ASSOC)));
}

// GET /cities - cities with available listings, most listings first.
// cover_image is the cover photo of the city's most liked listing.
function cities_index()
{
    $stmt = db()->query(
        "SELECT c.city, c.state, c.listing_count,
                (SELECT i.file_path
                   FROM properties p
                   JOIN property_images i ON i.property_id = p.property_id
                  WHERE p.city = c.city AND p.status = 'available' AND i.is_hidden = 0
                  ORDER BY (SELECT COUNT(*) FROM likes l WHERE l.property_id = p.property_id) DESC,
                           p.property_id, i.sort_order, i.image_id
                  LIMIT 1) AS cover_image
         FROM (SELECT city, MAX(state) AS state, COUNT(*) AS listing_count
                 FROM properties
                WHERE status = 'available'
                GROUP BY city) c
         ORDER BY c.listing_count DESC, c.city"
    );
    json_out(array_map(function ($r) {
        return [
            'city'          => $r['city'],
            'state'         => $r['state'],
            'listing_count' => (int) $r['listing_count'],
            'cover_image'   => $r['cover_image'],
        ];
    }, $stmt->fetchAll(PDO::FETCH_ASSOC)));
}
