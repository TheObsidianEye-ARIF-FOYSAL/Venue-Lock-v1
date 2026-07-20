<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$venueId = (string) ($input['venueId'] ?? '');
$seatId = (string) ($input['seatId'] ?? '');
$reserve = (bool) ($input['reserve'] ?? true);
$guestName = (string) ($input['guestName'] ?? '');

$db = venuelock_db();
$user = venuelock_require_session($db, $phone, $token);

if ($venueId === '' || $seatId === '') {
    venuelock_send_json(['error' => 'venueId and seatId are required'], 400);
}

$venueStmt = $db->prepare('SELECT admin_phone FROM venues WHERE id = ?');
$venueStmt->execute([$venueId]);
$venue = $venueStmt->fetch(PDO::FETCH_ASSOC);
if (!$venue || $venue['admin_phone'] !== $user['phone']) {
    venuelock_send_json(['error' => 'Venue not found'], 404);
}

$db->beginTransaction();
try {
    if ($reserve) {
        // Only a currently-available seat can be reserved for a guest — a
        // seat already booked by an attendee must be released first.
        $update = $db->prepare(
            "UPDATE seats SET status = 'blocked', student_name = ?, student_email = NULL, roll_number = NULL, qr_token = NULL, booked_at = ?
             WHERE id = ? AND venue_id = ? AND status = 'available'"
        );
        $now = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);
        $update->execute([$guestName, $now, $seatId, $venueId]);

        if ($update->rowCount() === 0) {
            $db->rollBack();
            venuelock_send_json(['error' => 'Seat is not available to reserve'], 409);
        }
    } else {
        $update = $db->prepare(
            "UPDATE seats SET status = 'available', student_name = NULL, booked_at = NULL
             WHERE id = ? AND venue_id = ? AND status = 'blocked'"
        );
        $update->execute([$seatId, $venueId]);

        if ($update->rowCount() === 0) {
            $db->rollBack();
            venuelock_send_json(['error' => 'Seat is not currently reserved'], 409);
        }
    }

    $db->commit();
} catch (Exception $e) {
    $db->rollBack();
    venuelock_send_json(['error' => 'Reservation update failed'], 500);
}

venuelock_send_json(['ok' => true]);
