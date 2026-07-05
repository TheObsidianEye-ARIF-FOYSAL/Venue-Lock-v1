<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$accessCode = strtoupper(trim((string) ($input['accessCode'] ?? '')));
$name = trim((string) ($input['name'] ?? ''));
$phone = trim((string) ($input['phone'] ?? ''));

if ($accessCode === '' || $name === '') {
    venuelock_send_json(['error' => 'accessCode and name are required'], 400);
}

$db = venuelock_db();
$venueStmt = $db->prepare('SELECT * FROM venues WHERE access_code = ? LIMIT 1');
$venueStmt->execute([$accessCode]);
$venue = $venueStmt->fetch(PDO::FETCH_ASSOC);

if (!$venue) {
    venuelock_send_json(['error' => 'Invalid venue code'], 404);
}

$id = bin2hex(random_bytes(8));
$deviceToken = bin2hex(random_bytes(16));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$insert = $db->prepare(
    'INSERT INTO volunteers (id, venue_id, name, phone, status, device_token, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)'
);
$insert->execute([$id, $venue['id'], $name, $phone, 'pending', $deviceToken, $now]);

venuelock_send_json([
    'volunteerId' => $id,
    'deviceToken' => $deviceToken,
    'venueId' => $venue['id'],
    'venueName' => $venue['name'],
]);
