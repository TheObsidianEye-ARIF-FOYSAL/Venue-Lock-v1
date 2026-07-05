<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$volunteerId = (string) ($input['volunteerId'] ?? '');
$deviceToken = (string) ($input['deviceToken'] ?? '');

if ($volunteerId === '' || $deviceToken === '') {
    venuelock_send_json(['error' => 'volunteerId and deviceToken are required'], 400);
}

$db = venuelock_db();
$stmt = $db->prepare('SELECT * FROM volunteers WHERE id = ? LIMIT 1');
$stmt->execute([$volunteerId]);
$volunteer = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$volunteer || !hash_equals($volunteer['device_token'], $deviceToken)) {
    venuelock_send_json(['error' => 'Volunteer application not found'], 404);
}

venuelock_send_json(venuelock_volunteer_payload($volunteer));
