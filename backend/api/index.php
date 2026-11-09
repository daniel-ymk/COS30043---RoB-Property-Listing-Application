<?php
// RoB Property REST API - front controller.
// Every request is routed here by .htaccess (or reached as index.php/<path>
// where mod_rewrite is off). Routes and payloads: docs/api.md.

require __DIR__ . '/_bootstrap.php';
require __DIR__ . '/_queries.php';

// [method, path pattern, resource file, handler function]
// Captured groups are passed to the handler as integer arguments.
function routes()
{
    return [
    // session and accounts
    ['GET',    'session',                 'session',      'session_show'],
    ['POST',   'session',                 'session',      'session_create'],
    ['DELETE', 'session',                 'session',      'session_remove'],
    ['POST',   'users',                   'session',      'users_create'],
    ['PATCH',  'me',                      'me',           'me_update'],

    // properties
    ['GET',    'properties',              'properties',   'properties_index'],
    ['POST',   'properties',              'properties',   'properties_create'],
    ['GET',    'properties/(\d+)',        'properties',   'properties_show'],
    ['PUT',    'properties/(\d+)',        'properties',   'properties_update'],
    ['PATCH',  'properties/(\d+)',        'properties',   'properties_set_status'],
    ['DELETE', 'properties/(\d+)',        'properties',   'properties_destroy'],
    ['GET',    'me/properties',           'properties',   'properties_mine'],
    ['GET',    'cities',                  'map',          'cities_index'],

    // photos
    ['POST',   'properties/(\d+)/images', 'images',       'images_create'],
    ['PUT',    'properties/(\d+)/images', 'images',       'images_reorder'],
    ['PATCH',  'images/(\d+)',            'images',       'images_update'],
    ['DELETE', 'images/(\d+)',            'images',       'images_destroy'],

    // likes
    ['GET',    'me/likes',                'likes',        'likes_index'],
    ['PUT',    'me/likes/(\d+)',          'likes',        'likes_create'],
    ['DELETE', 'me/likes/(\d+)',          'likes',        'likes_destroy'],

    // viewing days
    ['GET',    'properties/(\d+)/slots',  'slots',        'slots_for_property'],
    ['GET',    'me/slots',                'slots',        'slots_mine'],
    ['POST',   'me/slots',                'slots',        'slots_create'],
    ['DELETE', 'me/slots/(\d+)',          'slots',        'slots_destroy'],

    // viewings
    ['POST',   'appointments',            'appointments', 'appointments_create'],
    ['GET',    'me/appointments',         'appointments', 'appointments_index'],
    ['PATCH',  'appointments/(\d+)',      'appointments', 'appointments_update'],

    // map search
    ['GET',    'map',                     'map',          'map_index'],
];
}

// Path after the API folder, e.g. "properties/5" (works with or without /index.php)
function request_path()
{
    if (!empty($_SERVER['PATH_INFO'])) {
        return trim($_SERVER['PATH_INFO'], '/');
    }
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    $base = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/');
    if ($base !== '' && strpos($path, $base) === 0) {
        $path = substr($path, strlen($base));
    }
    $path = preg_replace('#^/index\.php#', '', $path);
    return trim(rawurldecode($path), '/');
}

$method = $_SERVER['REQUEST_METHOD'];
$path = request_path();
$allowed = [];

foreach (routes() as $route) {
    list($routeMethod, $pattern, $file, $handler) = $route;
    if (!preg_match('#^' . $pattern . '$#', $path, $m)) {
        continue;
    }
    if ($routeMethod !== $method) {
        $allowed[] = $routeMethod;
        continue;
    }
    $resource = __DIR__ . "/resources/$file.php";
    if (!is_file($resource)) {
        fail(501, 'Not implemented yet');
    }
    require $resource;
    if (!function_exists($handler)) {
        fail(501, 'Not implemented yet');
    }
    try {
        call_user_func_array($handler, array_map('intval', array_slice($m, 1)));
    } catch (PDOException $e) {
        error_log('RoB API: ' . $e->getMessage());
        fail(500, 'Server error, please try again');
    }
    exit;
}

if ($allowed) {
    header('Allow: ' . implode(', ', array_unique($allowed)));
    fail(405, 'Method not allowed');
}
fail(404, 'No such API route');
