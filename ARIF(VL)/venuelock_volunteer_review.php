<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$venueId = (string) ($input['venueId'] ?? '');
$volunteerId = (string) ($input['volunteerId'] ?? '');
$action = (string) ($input['action'] ?? '');

$db = venuelock_db();
$user = venuelock_require_session($db, $phone, $token);

if ($venueId === '' || $volunteerId === '' || !in_array($action, ['approve', 'reject'], true)) {
    venuelock_send_json(['error' => 'venueId, volunteerId and a valid action are required'], 400);
}

$venueStmt = $db->prepare('SELECT admin_phone FROM venues WHERE id = ?');
$venueStmt->execute([$venueId]);
$venue = $venueStmt->fetch(PDO::FETCH_ASSOC);
if (!$venue || $venue['admin_phone'] !== $user['phone']) {
    venuelock_send_json(['error' => 'Venue not found'], 404);
}

$status = $action === 'approve' ? 'approved' : 'rejected';
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$update = $db->prepare(
    "UPDATE volunteers SET status = ?, decided_at = ? WHERE id = ? AND venue_id = ?"
);
$update->execute([$status, $now, $volunteerId, $venueId]);

if ($update->rowCount() === 0) {
    venuelock_send_json(['error' => 'Volunteer application not found'], 404);
}

venuelock_send_json(['ok' => true]);
