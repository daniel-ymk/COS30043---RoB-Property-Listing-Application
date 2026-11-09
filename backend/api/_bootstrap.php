<?php
// Shared setup for every API request: session, JSON responses, auth and
// validation helpers. Loaded once by index.php. Response format: docs/api.md §1.

// Same clock as MySQL (db.php runs SET time_zone = '+08:00'), so PHP's
// "today" matches the database's CURDATE() when checking viewing days
date_default_timezone_set('Asia/Kuala_Lumpur');

define('REMEMBER_SECONDS', 30 * 24 * 60 * 60); // "Keep me logged in" lasts 30 days

// Keep session files as long as a remembered login, or PHP's cleanup
// would end those sessions after 24 minutes of inactivity.
ini_set('session.gc_maxlifetime', (string) REMEMBER_SECONDS);
// Written for PHP 5.4 and up: Mercury runs PHP 5.x, XAMPP runs PHP 8.
// So no ??, no arrow functions, no scalar or return type declarations,
// no array constants (use functions), and helpers below for newer built-ins.

// $array[$key], or $default when it is missing or null (PHP 7's ?? operator)
function pick($array, $key, $default = null)
{
    return isset($array[$key]) ? $array[$key] : $default;
}

// Sets the session cookie: $expires = 0 (until the browser closes), a
// timestamp, or a past time to delete it. SameSite=Lax keeps the cookie
// off cross-site requests (CSRF); PHP before 7.3 has no samesite option,
// so it rides on the path attribute there.
function set_session_cookie($value, $expires)
{
    if (PHP_VERSION_ID >= 70300) {
        setcookie(session_name(), $value, [
            'expires'  => $expires,
            'path'     => '/',
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
    } else {
        setcookie(session_name(), $value, $expires, '/; samesite=Lax', '', false, true);
    }
}

// Own cookie name: every PHP app on a shared host like Mercury would
// otherwise share "PHPSESSID" on path / and log each other out
session_name('ROB_SESSION');
if (PHP_VERSION_ID >= 70300) {
    session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax']);
} else {
    session_set_cookie_params(0, '/; samesite=Lax', '', false, true);
}
session_start();

// password_hash / password_verify arrived in PHP 5.5; same bcrypt ($2y$)
// format, so seed hashes and new accounts work on either version
if (!function_exists('password_hash')) {
    define('PASSWORD_DEFAULT', 1);

    function password_hash($password, $algo)
    {
        $salt = substr(strtr(base64_encode(random_hex_bytes(16)), '+', '.'), 0, 22);
        return crypt($password, '$2y$10$' . $salt);
    }

    function password_verify($password, $hash)
    {
        $check = crypt($password, $hash);
        if (!is_string($check) || strlen($check) !== strlen($hash)) {
            return false;
        }
        $diff = 0; // compare every character, so timing doesn't leak the hash
        for ($i = 0; $i < strlen($hash); $i++) {
            $diff |= ord($check[$i]) ^ ord($hash[$i]);
        }
        return $diff === 0;
    }
}

// Characters, not bytes ("é" is 1); mbstring may be missing on old hosts
function text_length($text)
{
    return function_exists('mb_strlen') ? mb_strlen($text, 'UTF-8') : strlen(utf8_decode($text));
}

// Random bytes for file names and salts (random_bytes is PHP 7)
function random_hex_bytes($length)
{
    if (function_exists('random_bytes')) {
        return random_bytes($length);
    }
    if (function_exists('openssl_random_pseudo_bytes')) {
        return openssl_random_pseudo_bytes($length);
    }
    $bytes = '';
    for ($i = 0; $i < $length; $i++) {
        $bytes .= chr(mt_rand(0, 255));
    }
    return $bytes;
}

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

// Both define $pdo. db.local.php (XAMPP) wins when present; Mercury only has db.php.
$localDb = __DIR__ . '/../config/db.local.php';
require is_file($localDb) ? $localDb : __DIR__ . '/../config/db.php';

// ---------- responses ----------

function json_out($data, $code = 200, array $meta = null)
{
    http_response_code($code);
    if ($code === 204) {
        exit;
    }
    $out = ['data' => $data];
    if ($meta !== null) {
        $out['meta'] = $meta;
    }
    echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function fail($code, $message, array $fields = null)
{
    http_response_code($code);
    $out = ['error' => $message];
    if ($fields) {
        $out['fields'] = $fields;
    }
    echo json_encode($out, JSON_UNESCAPED_UNICODE);
    exit;
}

// JSON request body as an array ([] when empty or not JSON).
function body()
{
    $type = pick($_SERVER, 'CONTENT_TYPE', '');
    if (stripos($type, 'application/json') !== 0) {
        return [];
    }
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        fail(400, 'Malformed JSON body');
    }
    return $data;
}

// ---------- auth ----------

function db()
{
    global $pdo;
    return $pdo;
}

function current_user_id()
{
    return (int) (pick($_SESSION, 'user_id', 0));
}

function current_user()
{
    static $user = false;
    if ($user === false) {
        $user = null;
        if (current_user_id()) {
            $stmt = db()->prepare(
                'SELECT user_id, full_name, email, role, phone, created_at FROM users WHERE user_id = ?'
            );
            $stmt->execute([current_user_id()]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $user = $row ? user_row($row) : null;
        }
    }
    return $user;
}

function require_user()
{
    $user = current_user();
    if (!$user) {
        fail(401, 'Please log in first');
    }
    return $user;
}

function require_owner()
{
    $user = require_user();
    if ($user['role'] !== 'owner') {
        fail(403, 'Only owners can do this');
    }
    return $user;
}

function user_row(array $row)
{
    return [
        'user_id'    => (int) $row['user_id'],
        'full_name'  => $row['full_name'],
        'email'      => $row['email'],
        'role'       => $row['role'],
        'phone'      => $row['phone'],
        'created_at' => $row['created_at'],
    ];
}

// ---------- paging ----------

// [limit, offset, page, per_page] from ?page= & ?per_page= (default 12, max 48)
function paging()
{
    $page = max(1, (int) (pick($_GET, 'page', 1)));
    $perPage = (int) (pick($_GET, 'per_page', 12));
    $perPage = min(48, max(1, $perPage));
    return [$perPage, ($page - 1) * $perPage, $page, $perPage];
}

function page_meta($total, $page, $perPage)
{
    return [
        'page'        => $page,
        'per_page'    => $perPage,
        'total'       => $total,
        'total_pages' => (int) ceil($total / $perPage),
    ];
}

// ---------- validation (rules and messages: docs/api.md §4) ----------

class Validator
{
    private $input;
    public $errors = [];

    public function __construct(array $input)
    {
        $this->input = $input;
    }

    public function value($field)
    {
        $v = pick($this->input, $field);
        return is_string($v) ? trim($v) : $v;
    }

    private function blank($field)
    {
        $v = $this->value($field);
        return $v === null || $v === '';
    }

    private function add($field, $message)
    {
        if (!isset($this->errors[$field])) {
            $this->errors[$field] = $message;
        }
    }

    public function text($field, $min, $max, $required, $message)
    {
        if ($this->blank($field)) {
            if ($required) {
                $this->add($field, $message);
            }
            return $this;
        }
        $v = $this->value($field);
        $len = is_string($v) ? text_length($v) : -1;
        if ($len < $min || $len > $max) {
            $this->add($field, $message);
        }
        return $this;
    }

    public function email($field)
    {
        $v = $this->value($field);
        if ($this->blank($field) || !filter_var($v, FILTER_VALIDATE_EMAIL) || text_length($v) > 150) {
            $this->add($field, 'Enter a valid email address');
        }
        return $this;
    }

    public function oneOf($field, array $allowed, $message)
    {
        if (!in_array($this->value($field), $allowed, true)) {
            $this->add($field, $message);
        }
        return $this;
    }

    public function number($field, $min, $max, $required, $message, $integer = false)
    {
        if ($this->blank($field)) {
            if ($required) {
                $this->add($field, $message);
            }
            return $this;
        }
        $v = $this->value($field);
        $isNumber = $integer ? filter_var($v, FILTER_VALIDATE_INT) !== false : is_numeric($v);
        $ok = $isNumber && $v >= $min && $v <= $max;
        if (!$ok) {
            $this->add($field, $message);
        }
        return $this;
    }

    public function digits($field, $min, $max, $required, $message)
    {
        if ($this->blank($field)) {
            if ($required) {
                $this->add($field, $message);
            }
            return $this;
        }
        if (!preg_match('/^\d{' . $min . ',' . $max . '}$/', (string) $this->value($field))) {
            $this->add($field, $message);
        }
        return $this;
    }

    public function check($ok, $field, $message)
    {
        if (!$ok) {
            $this->add($field, $message);
        }
        return $this;
    }

    // Sends 422 with every field message if anything failed.
    public function done()
    {
        if ($this->errors) {
            fail(422, 'Validation failed', $this->errors);
        }
    }
}
