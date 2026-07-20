<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$venueId = (string) ($input['venueId'] ?? '');
$volunteerId = (string) ($input['volunteerId'] ?? '');
$deviceToken = (string) ($input['deviceToken'] ?? '');
$qrToken = (string) ($input['qrToken'] ?? '');

if ($venueId === '' || $volunteerId === '' || $deviceToken === '' || $qrToken === '') {
    venuelock_send_json(['error' => 'venueId, volunteerId, deviceToken and qrToken are required'], 400);
}

$db = venuelock_db();

$vStmt = $db->prepare('SELECT * FROM volunteers WHERE id = ? AND venue_id = ? LIMIT 1');
$vStmt->execute([$volunteerId, $venueId]);
$volunteer = $vStmt->fetch(PDO::FETCH_ASSOC);

if (!$volunteer || !hash_equals($volunteer['device_token'], $deviceToken)) {
    venuelock_send_json(['error' => 'Volunteer not recognized'], 401);
}
if ($volunteer['status'] !== 'approved') {
    venuelock_send_json(['error' => 'Volunteer is not approved for this venue'], 403);
}

$stmt = $db->prepare('SELECT * FROM seats WHERE qr_token = ? AND venue_id = ? LIMIT 1');
$stmt->execute([$qrToken, $venueId]);
$seat = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$seat) {
    venuelock_send_json(['error' => 'Seat not found'], 404);
}

$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$db->beginTransaction();
try {
    $update = $db->prepare(
        "UPDATE seats SET checked_in = 1, checked_in_at = ? WHERE qr_token = ? AND venue_id = ? AND checked_in = 0"
    );
    $update->execute([$now, $qrToken, $venueId]);

    if ($update->rowCount() === 0) {
        $db->rollBack();
        venuelock_send_json(['error' => 'Already checked in'], 409);
    }

    $db->prepare('UPDATE venues SET checked_in_count = checked_in_count + 1 WHERE id = ?')->execute([$venueId]);
    $db->commit();
} catch (Exception $e) {
    $db->rollBack();
    venuelock_send_json(['error' => 'Check-in failed'], 500);
}

venuelock_send_json(['studentName' => $seat['student_name']]);
