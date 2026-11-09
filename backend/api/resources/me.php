<?php
// The logged-in user's own profile. docs/api.md §3.8

// PATCH /me {full_name?, phone?} - only the fields sent are changed
function me_update()
{
    $user = require_user();
    $in = body();
    $v = new Validator($in);
    $sets = [];
    $params = [];

    if (array_key_exists('full_name', $in)) {
        $v->text('full_name', 2, 100, true, 'Enter your full name (2–100 characters)');
        $sets[] = 'full_name = ?';
        $params[] = $v->value('full_name');
    }
    if (array_key_exists('phone', $in)) {
        // Owners must keep a number: renters contact them on WhatsApp
        $v->digits('phone', 8, 15, $user['role'] === 'owner',
            'Use digits only, starting with the country code (8–15 digits)');
        $phone = (string) $v->value('phone');
        $sets[] = 'phone = ?';
        $params[] = $phone === '' ? null : $phone;
    }
    $v->done();

    if ($sets) {
        $params[] = $user['user_id'];
        $stmt = db()->prepare(
            'UPDATE users SET ' . implode(', ', $sets) . ' WHERE user_id = ?'
        );
        $stmt->execute($params);
    }

    $stmt = db()->prepare(
        'SELECT user_id, full_name, email, role, phone, created_at FROM users WHERE user_id = ?'
    );
    $stmt->execute([$user['user_id']]);
    json_out(user_row($stmt->fetch(PDO::FETCH_ASSOC)));
}
