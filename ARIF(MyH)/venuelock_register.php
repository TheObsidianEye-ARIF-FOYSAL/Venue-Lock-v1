<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

// The phone is already verified as a real subscriber by the carrier-billing
// OTP gate (send_otp.php / verify_otp.php) before the app ever reaches this
// registration form, so no separate OTP check is required here.
$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$name = trim((string) ($input['name'] ?? ''));
$password = (string) ($input['password'] ?? '');

if (strlen($phone) !== 11) {
    venuelock_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}
if ($name === '') {
    venuelock_send_json(['error' => 'Name is required'], 400);
}
if (strlen($password) < 6) {
    venuelock_send_json(['error' => 'Password must be at least 6 characters'], 400);
}

$db = venuelock_db();

$stmt = $db->prepare('SELECT 1 FROM users WHERE phone = ?');
$stmt->execute([$phone]);
if ($stmt->fetchColumn()) {
    venuelock_send_json(['error' => 'This phone number is already registered'], 409);
}

$passwordHash = password_hash($password, PASSWORD_BCRYPT);
$createdAt = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
$token = bin2hex(random_bytes(32));

$insert = $db->prepare(
    'INSERT INTO users (phone, name, password_hash, created_at, session_token, session_created_at)
     VALUES (?, ?, ?, ?, ?, ?)'
);
$insert->execute([$phone, $name, $passwordHash, $createdAt, $token, $createdAt]);

venuelock_send_json([
    'phone' => $phone,
    'name' => $name,
    'token' => $token,
]);
