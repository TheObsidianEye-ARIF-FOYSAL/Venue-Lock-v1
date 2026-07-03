<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

// Used to restore a session on app start (validates the stored token).
$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');

$db = venuelock_db();
$user = venuelock_require_session($db, $phone, $token);

venuelock_send_json(venuelock_user_payload($user));
