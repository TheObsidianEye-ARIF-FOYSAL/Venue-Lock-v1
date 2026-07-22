<?php

date_default_timezone_set('Asia/Dhaka');

// Shared SQLite storage + helpers for the VenueLock app's phone+password
// auth and venue/seat data (venuelock_*.php). Kept separate from the other
// *.php files in this folder so other apps using send_otp.php /
// verify_otp.php / unsubscribe.php are unaffected.

/// Where the SQLite file lives. Deliberately *outside* this folder:
///  • sitting next to the PHP files it was downloadable over HTTP, exposing
///    accounts, password hashes and attendee details to anyone;
///  • it also kept disappearing from that folder (host cleanup or a malware
///    scanner, cause unconfirmed), and since PDO recreates a missing SQLite
///    file silently, every account and booking vanished without a single
///    error in any response.
/// Falls back to the old location only if the new directory cannot be
/// created, so a permissions problem degrades instead of breaking.
function venuelock_db_path(): string {
    $legacy = __DIR__ . '/venuelock.db';
    $dir = dirname(__DIR__) . '/venuelock_data';

    if (!is_dir($dir) && !@mkdir($dir, 0700, true) && !is_dir($dir)) {
        return $legacy;
    }

    // Belt and braces in case the directory ends up web-accessible anyway.
    $htaccess = $dir . '/.htaccess';
    if (!file_exists($htaccess)) {
        @file_put_contents($htaccess, "Require all denied\n");
    }

    $path = $dir . '/venuelock.db';

    // One-time migration: adopt an existing database from the old location.
    if (!file_exists($path) && file_exists($legacy)) {
        if (@copy($legacy, $path)) {
            @rename($legacy, $legacy . '.migrated');
        } else {
            return $legacy;
        }
    }

    return $path;
}

function venuelock_db(): PDO {
    $dbPath = venuelock_db_path();
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        phone TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        session_token TEXT,
        session_created_at TEXT
    )");
    $pdo->exec("CREATE TABLE IF NOT EXISTS venues (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        event_date TEXT NOT NULL,
        sections_json TEXT NOT NULL,
        access_code TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        booked_count INTEGER NOT NULL DEFAULT 0,
        checked_in_count INTEGER NOT NULL DEFAULT 0,
        admin_phone TEXT NOT NULL,
        created_at TEXT NOT NULL
    )");
    $pdo->exec("CREATE TABLE IF NOT EXISTS seats (
        id TEXT NOT NULL,
        venue_id TEXT NOT NULL,
        row INTEGER,
        col INTEGER,
        section TEXT,
        status TEXT NOT NULL DEFAULT 'available',
        student_name TEXT,
        student_email TEXT,
        roll_number TEXT,
        qr_token TEXT,
        checked_in INTEGER NOT NULL DEFAULT 0,
        checked_in_at TEXT,
        booked_at TEXT,
        PRIMARY KEY (id, venue_id)
    )");
    $pdo->exec("CREATE TABLE IF NOT EXISTS volunteers (
        id TEXT PRIMARY KEY,
        venue_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        device_token TEXT NOT NULL,
        created_at TEXT NOT NULL,
        decided_at TEXT
    )");
    return $pdo;
}

// Mirrors the normalize logic used by the Flutter SubscriptionService so the
// phone primary key is consistent between the BDApps OTP step and this DB.
function venuelock_normalize_phone(string $phone): string {
    $digits = preg_replace('/\D/', '', $phone) ?? '';
    if (strpos($digits, '880') === 0 && strlen($digits) > 10) {
        return substr($digits, 3);
    }
    if (strpos($digits, '88') === 0 && strlen($digits) > 11) {
        return substr($digits, 2);
    }
    return $digits;
}

function venuelock_json_input(): array {
    $body = file_get_contents('php://input');
    $data = json_decode($body, true);
    if (is_array($data)) return $data;
    return $_POST;
}

function venuelock_send_json($data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function venuelock_cors(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function venuelock_require_session(PDO $db, string $phone, string $token): array {
    if ($phone === '' || $token === '') {
        venuelock_send_json(['error' => 'Invalid session'], 401);
    }
    $stmt = $db->prepare('SELECT * FROM users WHERE phone = ?');
    $stmt->execute([$phone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$user || !is_string($user['session_token']) || !hash_equals($user['session_token'], $token)) {
        venuelock_send_json(['error' => 'Invalid session'], 401);
    }
    return $user;
}

function venuelock_user_payload(array $user): array {
    return [
        'phone' => $user['phone'],
        'name' => $user['name'],
    ];
}

function venuelock_venue_payload(array $venue): array {
    return [
        'id' => $venue['id'],
        'name' => $venue['name'],
        'eventDate' => $venue['event_date'],
        'sections' => json_decode($venue['sections_json'], true) ?? [],
        'accessCode' => $venue['access_code'],
        'status' => $venue['status'],
        'bookedCount' => (int) $venue['booked_count'],
        'checkedInCount' => (int) $venue['checked_in_count'],
        'adminId' => $venue['admin_phone'],
    ];
}

function venuelock_volunteer_payload(array $v): array {
    return [
        'id' => $v['id'],
        'venueId' => $v['venue_id'],
        'name' => $v['name'],
        'phone' => $v['phone'],
        'status' => $v['status'],
        'createdAt' => $v['created_at'],
    ];
}

function venuelock_seat_payload(array $seat): array {
    return [
        'id' => $seat['id'],
        'row' => (int) $seat['row'],
        'col' => (int) $seat['col'],
        'section' => $seat['section'],
        'status' => $seat['status'],
        'studentName' => $seat['student_name'],
        'studentEmail' => $seat['student_email'],
        'rollNumber' => $seat['roll_number'],
        'qrToken' => $seat['qr_token'],
        'checkedIn' => (bool) $seat['checked_in'],
        'checkedInAt' => $seat['checked_in_at'],
        'bookedAt' => $seat['booked_at'],
    ];
}
