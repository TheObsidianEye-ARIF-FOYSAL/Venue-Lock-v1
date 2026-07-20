<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$venueId = (string) ($input['venueId'] ?? '');
$seatId = (string) ($input['seatId'] ?? '');
$studentName = (string) ($input['studentName'] ?? '');
$studentEmail = (string) ($input['studentEmail'] ?? '');
$rollNumber = (string) ($input['rollNumber'] ?? '');

if ($venueId === '' || $seatId === '') {
    venuelock_send_json(['error' => 'venueId and seatId are required'], 400);
}

$db = venuelock_db();
$qrToken = bin2hex(random_bytes(16));
$now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$db->beginTransaction();
try {
    $update = $db->prepare(
        "UPDATE seats SET status = 'booked', student_name = ?, student_email = ?, roll_number = ?, qr_token = ?, booked_at = ?
         WHERE id = ? AND venue_id = ? AND status = 'available'"
    );
    $update->execute([$studentName, $studentEmail, $rollNumber, $qrToken, $now, $seatId, $venueId]);

    if ($update->rowCount() === 0) {
        $db->rollBack();
        venuelock_send_json(['error' => 'Seat already booked'], 409);
    }

    $db->prepare('UPDATE venues SET booked_count = booked_count + 1 WHERE id = ?')->execute([$venueId]);
    $db->commit();
} catch (Exception $e) {
    $db->rollBack();
    venuelock_send_json(['error' => 'Booking failed'], 500);
}

venuelock_send_json(['qrToken' => $qrToken]);
