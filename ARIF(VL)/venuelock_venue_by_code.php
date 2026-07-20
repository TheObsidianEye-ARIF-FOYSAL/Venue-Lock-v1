<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$code = strtoupper((string) ($_GET['code'] ?? ''));
if ($code === '') {
    venuelock_send_json(['error' => 'Access code is required'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare("SELECT * FROM venues WHERE access_code = ? AND status = 'open' LIMIT 1");
$stmt->execute([$code]);
$venue = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$venue) {
    venuelock_send_json(['error' => 'Venue not found'], 404);
}

venuelock_send_json(venuelock_venue_payload($venue));
