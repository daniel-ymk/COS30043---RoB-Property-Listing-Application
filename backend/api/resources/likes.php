<?php
// Likes ("Save" / heart). docs/api.md §3.5

// GET /me/likes - the cards I liked, most recently liked first (any status,
// so a liked home that was rented still shows)
function likes_index()
{
    $user = require_user();
    list($limit, $offset, $page, $perPage) = paging();

    $count = db()->prepare('SELECT COUNT(*) FROM likes WHERE user_id = ?');
    $count->execute([$user['user_id']]);
    $total = (int) $count->fetchColumn();

    // LIMIT values are ints from paging(), safe to inline
    $stmt = db()->prepare(
        'SELECT ' . CARD_SELECT . "
         FROM likes mine
         JOIN properties p ON p.property_id = mine.property_id
         WHERE mine.user_id = :user
         ORDER BY mine.created_at DESC, p.property_id DESC
         LIMIT $limit OFFSET $offset"
    );
    $stmt->execute(['me' => $user['user_id'], 'user' => $user['user_id']]);
    json_out(array_map('card_row', $stmt->fetchAll(PDO::FETCH_ASSOC)), 200, page_meta($total, $page, $perPage));
}

// PUT /me/likes/:id - like (liking twice is fine)
function likes_create($propertyId)
{
    $user = require_user();
    $owner = like_target_owner($propertyId);
    if ($owner === $user['user_id']) {
        fail(403, "You can't like your own listing");
    }
    // INSERT IGNORE: the (user_id, property_id) primary key makes a repeat a no-op
    db()->prepare('INSERT IGNORE INTO likes (user_id, property_id) VALUES (?, ?)')
        ->execute([$user['user_id'], $propertyId]);
    like_result($propertyId, true);
}

// DELETE /me/likes/:id - unlike (unliking twice is fine)
function likes_destroy($propertyId)
{
    $user = require_user();
    like_target_owner($propertyId);
    db()->prepare('DELETE FROM likes WHERE user_id = ? AND property_id = ?')
        ->execute([$user['user_id'], $propertyId]);
    like_result($propertyId, false);
}

// Owner id of the listing, or 404 if it does not exist
function like_target_owner($propertyId)
{
    $stmt = db()->prepare('SELECT owner_id FROM properties WHERE property_id = ?');
    $stmt->execute([$propertyId]);
    $owner = $stmt->fetchColumn();
    if ($owner === false) {
        fail(404, 'Listing not found');
    }
    return (int) $owner;
}

// Fresh count so the heart button can update without reloading the page
function like_result($propertyId, $liked)
{
    $stmt = db()->prepare('SELECT COUNT(*) FROM likes WHERE property_id = ?');
    $stmt->execute([$propertyId]);
    json_out([
        'property_id' => $propertyId,
        'liked'       => $liked,
        'like_count'  => (int) $stmt->fetchColumn(),
    ]);
}
