<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$venueId = (string) ($_GET['venueId'] ?? '');
if ($venueId === '') {
    venuelock_send_json(['error' => 'Venue id is required'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare('SELECT * FROM seats WHERE venue_id = ?');
$stmt->execute([$venueId]);
$seats = array_map('venuelock_seat_payload', $stmt->fetchAll(PDO::FETCH_ASSOC));

venuelock_send_json(['seats' => $seats]);
