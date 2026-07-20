<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$password = (string) ($input['password'] ?? '');

$db = venuelock_db();
$user = venuelock_require_session($db, $phone, $token);

if (!password_verify($password, $user['password_hash'])) {
    venuelock_send_json(['error' => 'Incorrect password'], 401);
}

venuelock_send_json(['ok' => true]);
