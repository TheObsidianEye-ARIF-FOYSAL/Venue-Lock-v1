<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$id = (string) ($_GET['id'] ?? '');
if ($id === '') {
    venuelock_send_json(['error' => 'Venue id is required'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare('SELECT * FROM venues WHERE id = ?');
$stmt->execute([$id]);
$venue = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$venue) {
    venuelock_send_json(['error' => 'Venue not found'], 404);
}

venuelock_send_json(venuelock_venue_payload($venue));
