<?php
// Listing photos. docs/api.md §3.4

const MAX_PHOTOS = 10;
define('MAX_PHOTO_BYTES', 2 * 1024 * 1024);
// Real file type (from the bytes, not the name) => saved extension
function photo_types()
{
    return ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
}

// Room a photo shows (filters the gallery on the listing page)
function room_tags()
{
    return ['exterior', 'living', 'bedroom', 'kitchen', 'bathroom', 'dining', 'balcony', 'other'];
}

// Checks caption / room_tag / is_hidden in $in (JSON body or multipart form
// fields) and returns column => value for the ones that were sent.
function photo_details(array $in)
{
    $v = new Validator($in);
    $v->text('caption', 0, 150, false, 'Keep the caption to 150 characters');
    if (pick($in, 'room_tag', '') !== '') {
        $v->oneOf('room_tag', room_tags(), 'Choose a room from the list');
    }
    if (array_key_exists('is_hidden', $in)) {
        $v->check(in_array($in['is_hidden'], [true, false, 0, 1, '0', '1'], true), 'is_hidden', 'Choose shown or hidden');
    }
    $v->done();

    $details = [];
    if (array_key_exists('caption', $in)) {
        $caption = (string) $v->value('caption');
        $details['caption'] = $caption === '' ? null : $caption;
    }
    if (array_key_exists('room_tag', $in)) {
        $details['room_tag'] = $in['room_tag'] === '' || $in['room_tag'] === null ? null : $in['room_tag'];
    }
    if (array_key_exists('is_hidden', $in)) {
        $details['is_hidden'] = in_array($in['is_hidden'], [true, 1, '1'], true) ? 1 : 0;
    }
    return $details;
}

// POST /properties/:id/images - multipart field photos[] (one or more files)
// plus optional caption, room_tag and is_hidden for them. Added after the
// existing photos. Everything is checked before any file is saved.
// meta.created lists the new image ids, so the client can match its files.
function images_create($propertyId)
{
    require_own_property($propertyId);
    $files = uploaded_photos();
    if (!$files) {
        fail(422, 'Validation failed', ['photos' => 'Choose at least one photo']);
    }
    $details = photo_details($_POST);

    $count = db()->prepare('SELECT COUNT(*), COALESCE(MAX(sort_order), -1) FROM property_images WHERE property_id = ?');
    $count->execute([$propertyId]);
    list($existing, $lastOrder) = array_map('intval', $count->fetch(PDO::FETCH_NUM));
    if ($existing + count($files) > MAX_PHOTOS) {
        fail(422, 'Validation failed', [
            'photos' => 'A listing can have up to ' . MAX_PHOTOS . ' photos (' . $existing . ' already added)',
        ]);
    }

    $types = photo_types();
    foreach ($files as $file) {
        $name = $file['name'];
        if ($file['error'] === UPLOAD_ERR_INI_SIZE || $file['error'] === UPLOAD_ERR_FORM_SIZE
            || ($file['error'] === UPLOAD_ERR_OK && $file['size'] > MAX_PHOTO_BYTES)) {
            fail(422, 'Validation failed', ['photos' => "$name is larger than 2 MB"]);
        }
        if ($file['error'] !== UPLOAD_ERR_OK) {
            fail(422, 'Validation failed', ['photos' => "$name did not upload, please try again"]);
        }
        if (!isset($types[photo_mime($file['tmp_name'])])) {
            fail(422, 'Validation failed', ['photos' => "$name is not a JPEG, PNG or WebP image"]);
        }
    }

    $dir = UPLOAD_ROOT . '/' . $propertyId;
    if (!is_dir($dir) && !mkdir($dir, 0755, true)) {
        error_log("Cannot create $dir");
        fail(500, 'Could not save the photos, please try again');
    }

    $insert = db()->prepare(
        'INSERT INTO property_images (property_id, file_path, sort_order, caption, room_tag, is_hidden)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $created = [];
    foreach ($files as $file) {
        // Random name: nothing from the user's file name reaches the disk
        $ext = $types[photo_mime($file['tmp_name'])];
        $relative = "uploads/$propertyId/" . bin2hex(random_hex_bytes(12)) . ".$ext";
        if (!move_uploaded_file($file['tmp_name'], UPLOAD_ROOT . '/../' . $relative)) {
            error_log("Cannot move upload to $relative");
            fail(500, 'Could not save the photos, please try again');
        }
        $insert->execute([
            $propertyId,
            $relative,
            ++$lastOrder,
            pick($details, 'caption'),
            pick($details, 'room_tag'),
            pick($details, 'is_hidden', 0),
        ]);
        $created[] = (int) db()->lastInsertId();
    }

    json_out(listing_images($propertyId), 201, ['created' => $created]);
}

// PATCH /images/:id {caption?, room_tag?, is_hidden?} - only the fields sent
function images_update($imageId)
{
    $image = own_image($imageId);
    $details = photo_details(body());
    if ($details) {
        $sets = implode(', ', array_map(function ($column) {
            return "$column = ?";
        }, array_keys($details)));
        // Column names come from photo_details(), never from the request
        db()->prepare("UPDATE property_images SET $sets WHERE image_id = ?")
            ->execute(array_merge(array_values($details), [$imageId]));
    }
    foreach (listing_images((int) $image['property_id']) as $row) {
        if ($row['image_id'] === $imageId) {
            json_out($row);
        }
    }
}

// The photo row, after checking the listing belongs to the current owner
function own_image($imageId)
{
    $stmt = db()->prepare('SELECT property_id, file_path FROM property_images WHERE image_id = ?');
    $stmt->execute([$imageId]);
    $image = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$image) {
        fail(404, 'Photo not found');
    }
    require_own_property((int) $image['property_id']);
    return $image;
}

// PUT /properties/:id/images {order: [image_id, ...]} - new cover first.
// The list must name every photo of the listing exactly once.
function images_reorder($propertyId)
{
    require_own_property($propertyId);
    $order = pick(body(), 'order');
    $current = array_map(function ($image) {
        return $image['image_id'];
    }, listing_images($propertyId));

    $ok = is_array($order) && count($order) === count($current)
        && !array_diff($current, array_map('intval', $order))
        && count(array_unique(array_map('intval', $order))) === count($order);
    if (!$ok) {
        fail(422, 'Validation failed', ['order' => 'Send every photo id of this listing once']);
    }

    db()->beginTransaction();
    $stmt = db()->prepare('UPDATE property_images SET sort_order = ? WHERE image_id = ? AND property_id = ?');
    foreach (array_values($order) as $position => $imageId) {
        $stmt->execute([$position, (int) $imageId, $propertyId]);
    }
    db()->commit();
    json_out(listing_images($propertyId));
}

// DELETE /images/:id - row and file
function images_destroy($imageId)
{
    $image = own_image($imageId);

    db()->prepare('DELETE FROM property_images WHERE image_id = ?')->execute([$imageId]);
    // Seed photos are shared between listings, so only uploads are removed
    $path = UPLOAD_ROOT . '/../' . $image['file_path'];
    if (strpos($image['file_path'], 'uploads/seed/') !== 0 && is_file($path)) {
        unlink($path);
    }
    json_out(null, 204);
}

// $_FILES['photos'] as a list of single files (PHP groups multi-file fields by key)
function uploaded_photos()
{
    $field = pick($_FILES, 'photos');
    if (!$field) {
        return [];
    }
    if (!is_array($field['name'])) {
        return $field['error'] === UPLOAD_ERR_NO_FILE ? [] : [$field];
    }
    $files = [];
    foreach (array_keys($field['name']) as $i) {
        if ($field['error'][$i] === UPLOAD_ERR_NO_FILE) {
            continue;
        }
        $files[] = [
            'name'     => basename((string) $field['name'][$i]),
            'tmp_name' => $field['tmp_name'][$i],
            'size'     => (int) $field['size'][$i],
            'error'    => (int) $field['error'][$i],
        ];
    }
    return $files;
}

// Real file type from the file's bytes, never its name. fileinfo may be
// missing on older hosts; getimagesize() is always there (it reads the
// header the same way, but knows WebP only from PHP 7.1).
function photo_mime($path)
{
    if (class_exists('finfo')) {
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        return $finfo->file($path);
    }
    $info = @getimagesize($path);
    return $info ? $info['mime'] : '';
}
