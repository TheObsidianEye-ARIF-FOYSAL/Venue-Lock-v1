<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');

$db = venuelock_db();
venuelock_require_session($db, $phone, $token);

$stmt = $db->prepare('SELECT * FROM venues WHERE admin_phone = ? ORDER BY event_date ASC');
$stmt->execute([$phone]);
$venues = array_map('venuelock_venue_payload', $stmt->fetchAll(PDO::FETCH_ASSOC));

venuelock_send_json(['venues' => $venues]);
