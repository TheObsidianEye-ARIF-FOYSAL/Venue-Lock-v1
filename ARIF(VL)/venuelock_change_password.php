<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$currentPassword = (string) ($input['currentPassword'] ?? '');
$newPassword = (string) ($input['newPassword'] ?? '');

$db = venuelock_db();
$user = venuelock_require_session($db, $phone, $token);

if (!password_verify($currentPassword, $user['password_hash'])) {
    venuelock_send_json(['error' => 'Current password is incorrect'], 401);
}
if (strlen($newPassword) < 6) {
    venuelock_send_json(['error' => 'New password must be at least 6 characters'], 400);
}

$passwordHash = password_hash($newPassword, PASSWORD_BCRYPT);
$db->prepare('UPDATE users SET password_hash = ? WHERE phone = ?')->execute([$passwordHash, $phone]);

venuelock_send_json(['success' => true]);
