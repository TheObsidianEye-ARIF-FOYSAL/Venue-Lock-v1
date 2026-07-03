<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$venueId = (string) ($input['venueId'] ?? '');
$qrToken = (string) ($input['qrToken'] ?? '');

$db = venuelock_db();
venuelock_require_session($db, $phone, $token);

if ($venueId === '' || $qrToken === '') {
    venuelock_send_json(['error' => 'venueId and qrToken are required'], 400);
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
