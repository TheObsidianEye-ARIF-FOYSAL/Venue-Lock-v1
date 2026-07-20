<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

// Called only after the client has already verified a BDApps OTP for this
// phone number (see verify_otp.php) — the same trust model registration
// uses, since this server has no email/SMS channel of its own to send a
// reset link/code through.
$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$password = (string) ($input['password'] ?? '');

if (strlen($phone) !== 11) {
    venuelock_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}
if (strlen($password) < 6) {
    venuelock_send_json(['error' => 'Password must be at least 6 characters'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare('SELECT * FROM users WHERE phone = ?');
$stmt->execute([$phone]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$user) {
    venuelock_send_json(['error' => 'No account found for this phone number'], 404);
}

$passwordHash = password_hash($password, PASSWORD_BCRYPT);
$token = bin2hex(random_bytes(32));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

// Rotate the session token too, so any other device that was logged in is
// signed out once the password is reset.
$update = $db->prepare(
    'UPDATE users SET password_hash = ?, session_token = ?, session_created_at = ? WHERE phone = ?'
);
$update->execute([$passwordHash, $token, $now, $phone]);

venuelock_send_json(venuelock_user_payload($user) + ['token' => $token]);
