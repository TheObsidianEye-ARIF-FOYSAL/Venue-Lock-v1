<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$password = (string) ($input['password'] ?? '');

if (strlen($phone) !== 11) {
    venuelock_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare('SELECT * FROM users WHERE phone = ?');
$stmt->execute([$phone]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    venuelock_send_json(['error' => 'No account found for this phone number'], 404);
}
if (!password_verify($password, $user['password_hash'])) {
    venuelock_send_json(['error' => 'Incorrect password'], 401);
}

$token = bin2hex(random_bytes(32));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
$update = $db->prepare('UPDATE users SET session_token = ?, session_created_at = ? WHERE phone = ?');
$update->execute([$token, $now, $phone]);

$user['session_token'] = $token;
venuelock_send_json(venuelock_user_payload($user) + ['token' => $token]);
