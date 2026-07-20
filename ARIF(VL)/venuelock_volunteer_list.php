<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$venueId = (string) ($input['venueId'] ?? '');

$db = venuelock_db();
$user = venuelock_require_session($db, $phone, $token);

if ($venueId === '') {
    venuelock_send_json(['error' => 'venueId is required'], 400);
}

$venueStmt = $db->prepare('SELECT admin_phone FROM venues WHERE id = ?');
$venueStmt->execute([$venueId]);
$venue = $venueStmt->fetch(PDO::FETCH_ASSOC);
if (!$venue || $venue['admin_phone'] !== $user['phone']) {
    venuelock_send_json(['error' => 'Venue not found'], 404);
}

$stmt = $db->prepare('SELECT * FROM volunteers WHERE venue_id = ? ORDER BY created_at DESC');
$stmt->execute([$venueId]);
$volunteers = array_map('venuelock_volunteer_payload', $stmt->fetchAll(PDO::FETCH_ASSOC));

venuelock_send_json(['volunteers' => $volunteers]);
