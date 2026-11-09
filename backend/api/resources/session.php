<?php
// Session (login state) and user accounts. docs/api.md §3.1

// GET /session - who is logged in (data: null for guests)
function session_show()
{
    json_out(current_user());
}

// POST /session {email, password, remember?} - log in
function session_create()
{
    $in = body();
    $email = trim((string) (pick($in, 'email', '')));
    $password = (string) (pick($in, 'password', ''));

    $stmt = db()->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    // Same message for a wrong email or a wrong password, so emails can't be probed
    if (!$row || !password_verify($password, $row['password_hash'])) {
        fail(401, 'Invalid email or password');
    }
    start_session_for((int) $row['user_id'], !empty($in['remember']));
    json_out(user_row($row));
}

// DELETE /session - log out
function session_remove()
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        set_session_cookie('', time() - 3600);
    }
    session_destroy();
    json_out(null, 204);
}

// POST /users {full_name, email, password, role, phone} - register and log in
function users_create()
{
    $in = body();
    $v = new Validator($in);
    $v->text('full_name', 2, 100, true, 'Enter your full name (2–100 characters)')
      ->email('email')
      ->oneOf('role', ['owner', 'viewer'], 'Choose viewer or owner');

    $password = (string) (pick($in, 'password', ''));
    $v->check(
        strlen($password) >= 8 && preg_match('/[A-Za-z]/', $password) && preg_match('/\d/', $password),
        'password',
        'Use at least 8 characters with a letter and a number'
    );
    $v->digits('phone', 8, 15, $v->value('role') === 'owner',
        'Use digits only, starting with the country code (8–15 digits)');

    if (!isset($v->errors['email'])) {
        $taken = db()->prepare('SELECT 1 FROM users WHERE email = ?');
        $taken->execute([$v->value('email')]);
        $v->check(!$taken->fetchColumn(), 'email', 'Email is already registered');
    }
    $v->done();

    $phone = $v->value('phone');
    $stmt = db()->prepare(
        'INSERT INTO users (full_name, email, password_hash, role, phone) VALUES (?, ?, ?, ?, ?)'
    );
    try {
        $stmt->execute([
            $v->value('full_name'),
            $v->value('email'),
            password_hash($password, PASSWORD_DEFAULT),
            $v->value('role'),
            $phone === '' ? null : $phone,
        ]);
    } catch (PDOException $e) {
        // Two sign-ups with the same email at the same moment
        if ($e->getCode() === '23000') {
            fail(422, 'Validation failed', ['email' => 'Email is already registered']);
        }
        throw $e;
    }

    start_session_for((int) db()->lastInsertId());
    json_out(current_user(), 201);
}

// $remember keeps the cookie after the browser closes; otherwise it ends with it
function start_session_for($userId, $remember = false)
{
    session_regenerate_id(true);
    $_SESSION['user_id'] = $userId;
    if ($remember) {
        set_session_cookie(session_id(), time() + REMEMBER_SECONDS);
    }
}
