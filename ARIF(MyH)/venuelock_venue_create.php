<?php

require __DIR__ . '/venuelock_db.php';
venuelock_cors();

$input = venuelock_json_input();
$phone = venuelock_normalize_phone((string) ($input['phone'] ?? ''));
$token = (string) ($input['token'] ?? '');
$name = trim((string) ($input['name'] ?? ''));
$eventDate = (string) ($input['eventDate'] ?? '');
$sections = $input['sections'] ?? [];

$db = venuelock_db();
venuelock_require_session($db, $phone, $token);

if ($name === '') {
    venuelock_send_json(['error' => 'Venue name is required'], 400);
}
if (!is_array($sections) || count($sections) === 0) {
    venuelock_send_json(['error' => 'At least one section is required'], 400);
}

function venuelock_generate_code(): string {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $code = '';
    for ($i = 0; $i < 6; $i++) {
        $code .= $chars[random_int(0, strlen($chars) - 1)];
    }
    return $code;
}

$id = bin2hex(random_bytes(16));
$accessCode = venuelock_generate_code();
$createdAt = (new DateTime('now', new DateTimeZone('UTC')))->format(DateTime::ATOM);

$db->beginTransaction();
try {
    $insertVenue = $db->prepare(
        'INSERT INTO venues (id, name, event_date, sections_json, access_code, status, booked_count, checked_in_count, admin_phone, created_at)
         VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?)'
    );
    $insertVenue->execute([$id, $name, $eventDate, json_encode($sections), $accessCode, 'open', $phone, $createdAt]);

    $insertSeat = $db->prepare(
        'INSERT INTO seats (id, venue_id, row, col, section, status)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    foreach ($sections as $section) {
        $sectionName = (string) ($section['name'] ?? '');
        $sanitizedId = (string) ($section['sanitizedId'] ?? preg_replace('/[^A-Za-z0-9]/', '', $sectionName));
        $rows = (int) ($section['rows'] ?? 0);
        $cols = (int) ($section['cols'] ?? 0);
        for ($r = 1; $r <= $rows; $r++) {
            for ($c = 1; $c <= $cols; $c++) {
                $seatId = "{$sanitizedId}_R{$r}C{$c}";
                $insertSeat->execute([$seatId, $id, $r, $c, $sectionName, 'available']);
            }
        }
    }

    $db->commit();
} catch (Exception $e) {
    $db->rollBack();
    venuelock_send_json(['error' => 'Failed to create venue'], 500);
}

$stmt = $db->prepare('SELECT * FROM venues WHERE id = ?');
$stmt->execute([$id]);
$venue = $stmt->fetch(PDO::FETCH_ASSOC);

venuelock_send_json(venuelock_venue_payload($venue));
