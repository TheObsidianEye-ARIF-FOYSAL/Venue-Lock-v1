<?php

require __DIR__ . '/bdapps_config.php';

// CORS: the Flutter web build (GitHub Pages demo) calls this from a
// different origin than the PHP host, so the browser needs these headers
// on every response (including the OPTIONS preflight) or it blocks the
// reply before the app ever sees it.
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// VenueLock OTP request (APP_139127). Approved for TESTING ONLY — BDApps
// issues OTPs for whitelisted test numbers on this app id until "Active
// Production" is granted; every other number comes back as an error, which
// this script forwards verbatim so the app can show the real reason.

$user_mobile = $_POST['user_mobile'] ?? '';
$user_mobile = 'tel:88' . $user_mobile;

$requestData = array(
    "applicationId" => BDAPPS_APP_ID,
    "password" => BDAPPS_APP_PASSWORD,
    "subscriberId" => "$user_mobile",
    "applicationHash" => "VenueLock",
    "applicationMetaData" => array(
        "client" => "MOBILEAPP",
        "device" => "Android",
        "os" => "android",
        "appCode" => "VenueLock"
    )
);

$requestJson = json_encode($requestData);

$url = "https://developer.bdapps.com/subscription/otp/request";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $requestJson);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, array(
    "Content-Type: application/json",
    "Content-Length: " . strlen($requestJson)
));

$responseJson = curl_exec($ch);

header('Content-Type: application/json');

if ($responseJson === false) {
    echo json_encode([
        'referenceNo' => null,
        'statusCode' => 'E1001',
        'statusDetail' => 'cURL error: ' . curl_error($ch),
    ]);
} else {
    $response = json_decode($responseJson, true);
    if ($response === null) {
        echo json_encode([
            'referenceNo' => null,
            'statusCode' => 'E1002',
            'statusDetail' => 'Invalid JSON in response: ' . $responseJson,
        ]);
    } else {
        $statusCode = $response['statusCode'] ?? null;
        // E1351 = subscriberId is already subscribed to this application.
        // BDApps' whitelisted test numbers are pre-subscribed, so no OTP is
        // ever issued for them — flag it so the app can treat the number as
        // already verified instead of dead-ending on "Unable to request OTP".
        $alreadyRegistered = $statusCode === 'E1351';
        echo json_encode([
            'referenceNo' => $response['referenceNo'] ?? null,
            'statusCode' => $statusCode,
            'statusDetail' => $response['statusDetail'] ?? null,
            'alreadyRegistered' => $alreadyRegistered,
        ]);
    }
}

curl_close($ch);
