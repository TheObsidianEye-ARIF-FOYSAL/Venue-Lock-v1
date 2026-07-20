<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));

if (strlen($phone) !== 11) {
    venuelock_send_json(['error' => 'Enter a valid 11-digit phone number'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare('SELECT 1 FROM users WHERE phone = ?');
$stmt->execute([$phone]);

venuelock_send_json(['exists' => (bool) $stmt->fetchColumn()]);
