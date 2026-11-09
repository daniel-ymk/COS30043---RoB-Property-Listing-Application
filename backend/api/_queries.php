<?php
// Shared property queries: the "Property card" and "Property detail" shapes
// from docs/api.md §2, built on the reference SQL in schema.sql.

// SELECT list for a card. Bind :me to the current user id (0 for guests).
const CARD_SELECT = "
    p.property_id, p.owner_id, p.title, p.listing_type, p.property_type, p.price,
    p.bedrooms, p.bathrooms, p.parking_spaces, p.floor_area_sqm, p.is_furnished,
    p.city, p.state, p.latitude, p.longitude, p.status, p.created_at,
    (SELECT i.file_path FROM property_images i
      WHERE i.property_id = p.property_id AND i.is_hidden = 0
      ORDER BY i.sort_order, i.image_id LIMIT 1)            AS cover_image,
    (SELECT COUNT(*) FROM likes l
      WHERE l.property_id = p.property_id)                   AS like_count,
    EXISTS (SELECT 1 FROM likes l
      WHERE l.property_id = p.property_id AND l.user_id = :me) AS liked_by_me
";

// Casts a DB row to the card shape (numbers as numbers, flags as booleans).
function card_row(array $r)
{
    return [
        'property_id'    => (int) $r['property_id'],
        'title'          => $r['title'],
        'listing_type'   => $r['listing_type'],
        'property_type'  => $r['property_type'],
        'price'          => (float) $r['price'],
        'bedrooms'       => (int) $r['bedrooms'],
        'bathrooms'      => (int) $r['bathrooms'],
        'parking_spaces' => (int) $r['parking_spaces'],
        'floor_area_sqm' => $r['floor_area_sqm'] === null ? null : (float) $r['floor_area_sqm'],
        'is_furnished'   => (bool) $r['is_furnished'],
        'city'           => $r['city'],
        'state'          => $r['state'],
        'latitude'       => $r['latitude'] === null ? null : (float) $r['latitude'],
        'longitude'      => $r['longitude'] === null ? null : (float) $r['longitude'],
        'status'         => $r['status'],
        'cover_image'    => $r['cover_image'],
        'like_count'     => (int) $r['like_count'],
        'liked_by_me'    => (bool) $r['liked_by_me'],
        // own listings get no like button (liking them is a 403)
        'is_mine'        => current_user_id() === (int) $r['owner_id'],
        'created_at'     => $r['created_at'],
    ];
}

// Full detail for one listing, or null if it does not exist.
function property_detail($id)
{
    $stmt = db()->prepare(
        'SELECT ' . CARD_SELECT . ', p.description, p.address, p.postcode, p.updated_at,
                u.full_name AS owner_name, u.phone AS owner_phone
         FROM properties p JOIN users u ON u.user_id = p.owner_id
         WHERE p.property_id = :id'
    );
    $stmt->execute(['me' => current_user_id(), 'id' => $id]);
    $r = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$r) {
        return null;
    }

    // The owner sees hidden photos too (to manage them); everyone else doesn't
    $isMine = current_user_id() === (int) $r['owner_id'];
    $detail = card_row($r) + [
        'description' => $r['description'],
        'address'     => $r['address'],
        'postcode'    => $r['postcode'],
        'updated_at'  => $r['updated_at'],
        'images'      => listing_images($id, $isMine),
        'owner'       => [
            'user_id'   => (int) $r['owner_id'],
            'full_name' => $r['owner_name'],
            // Guests never see the number (docs/api.md §2 guest visibility)
            'phone'     => current_user_id() ? $r['owner_phone'] : null,
        ],
    ];
    return $detail;
}

// Photos of a listing in order; hidden ones only when $withHidden (owner).
// Shape: docs/api.md §2 Image.
function listing_images($propertyId, $withHidden = true)
{
    $stmt = db()->prepare(
        'SELECT image_id, file_path, sort_order, caption, room_tag, is_hidden
         FROM property_images
         WHERE property_id = ?' . ($withHidden ? '' : ' AND is_hidden = 0') . '
         ORDER BY sort_order, image_id'
    );
    $stmt->execute([$propertyId]);
    return array_map('image_row', $stmt->fetchAll(PDO::FETCH_ASSOC));
}

function image_row(array $i)
{
    return [
        'image_id'   => (int) $i['image_id'],
        'file_path'  => $i['file_path'],
        'sort_order' => (int) $i['sort_order'],
        'caption'    => $i['caption'],
        'room_tag'   => $i['room_tag'],
        'is_hidden'  => (bool) $i['is_hidden'],
    ];
}

// backend/uploads; file_path values are relative to backend/
define('UPLOAD_ROOT', __DIR__ . '/../uploads');

// Deletes uploads/<property_id>/ and the photos in it.
function remove_upload_dir($propertyId)
{
    $dir = UPLOAD_ROOT . '/' . $propertyId;
    if (!is_dir($dir)) {
        return;
    }
    foreach (glob($dir . '/*') ?: [] as $file) {
        if (is_file($file)) {
            unlink($file);
        }
    }
    rmdir($dir);
}

// Loads a listing and stops with 404/403 unless the current user owns it.
function require_own_property($id)
{
    $user = require_owner();
    $stmt = db()->prepare('SELECT * FROM properties WHERE property_id = ?');
    $stmt->execute([$id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        fail(404, 'Listing not found');
    }
    if ((int) $row['owner_id'] !== $user['user_id']) {
        fail(403, 'This is not your listing');
    }
    return $row;
}
