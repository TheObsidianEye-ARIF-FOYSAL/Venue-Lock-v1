<?php

ini_set('error_log', 'ussd-app-error.log');
date_default_timezone_set('Asia/Dhaka');

// BDApps credentials
$appid = "APP_128956";
$apppassword = "a0b6805ae4de029d93def2a16d633b4a";

// Get the current date/time for logging
$date_ = date("Y-m-d h:i:sa");

// Read JSON input from Android app
$body = file_get_contents('php://input');
$request = json_decode($body, true);
// $test_number = '8801853505313';
// $request = array('subscriberId' => $test_number);

// Log the incoming request
try {
    $myfile = fopen("unsubscribe_requests.txt", "a+") or die("Unable to open file!");
    fwrite($myfile, "Request: " . $body . " Date: " . $date_ . "\n");
    fclose($myfile);
} catch (Exception $e) {
    // Silent fail
}

// Validate input
if (!isset($request['subscriberId']) || empty($request['subscriberId'])) {
    $errorResponse = array(
        "statusCode" => "E1000",
        "statusDetail" => "subscriberId is required",
        "subscriptionStatus" => "ERROR"
    );
    echo json_encode($errorResponse);
    exit;
}

$subscriberId = $request['subscriberId'];

// Ensure subscriberId is in correct format (tel:88...)
if (strpos($subscriberId, 'tel:') !== 0) {
    $subscriberId = 'tel:' . $subscriberId;
}

// Prepare unsubscribe request data for BDApps API
$requestData = array(
    "applicationId" => $appid,
    "password" => $apppassword,
    "version" => "1.0",
    "action" => "0",  // 0 = Unsubscribe (opt-out)
    "subscriberId" => $subscriberId
);

// Convert request data to JSON
$requestJson = json_encode($requestData);

// Log the outgoing BDApps request
try {
    $myfile = fopen("unsubscribe_bdapps_requests.txt", "a+") or die("Unable to open file!");
    fwrite($myfile, "BDApps Request: " . $requestJson . " Date: " . $date_ . "\n");
    fclose($myfile);
} catch (Exception $e) {
    // Silent fail
}

// cURL options for BDApps unsubscribe API
$url = "https://developer.bdapps.com/subscription/send";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $requestJson);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, array(
    "Content-Type: application/json",
    "Content-Length: " . strlen($requestJson)
));

// Send cURL request and get response
$responseJson = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

if ($responseJson === false) {
    // cURL error
    $errorMessage = curl_error($ch);
    
    // Log the error
    try {
        $myfile = fopen("unsubscribe_errors.txt", "a+") or die("Unable to open file!");
        fwrite($myfile, "cURL Error: " . $errorMessage . " Date: " . $date_ . "\n");
        fclose($myfile);
    } catch (Exception $e) {
        // Silent fail
    }
    
    $errorResponse = array(
        "statusCode" => "E1001",
        "statusDetail" => "cURL error: " . $errorMessage,
        "subscriptionStatus" => "ERROR"
    );
    echo json_encode($errorResponse);
    curl_close($ch);
    exit;
}

// Parse response
$response = json_decode($responseJson, true);

// Log the BDApps response
try {
    $myfile = fopen("unsubscribe_responses.txt", "a+") or die("Unable to open file!");
    fwrite($myfile, "BDApps Response: " . $responseJson . " HTTP Code: " . $httpCode . " Date: " . $date_ . "\n");
    fclose($myfile);
} catch (Exception $e) {
    // Silent fail
}

if ($response === null) {
    // Invalid JSON response
    $errorResponse = array(
        "statusCode" => "E1002",
        "statusDetail" => "Invalid JSON in response from BDApps",
        "subscriptionStatus" => "ERROR",
        "rawResponse" => $responseJson
    );
    echo json_encode($errorResponse);
    curl_close($ch);
    exit;
}

// Check if unsubscribe was successful
if (isset($response["statusCode"]) && $response["statusCode"] == "S1000") {
    // Success - user unsubscribed
    $successResponse = array(
        "statusCode" => $response["statusCode"],
        "statusDetail" => $response["statusDetail"],
        "subscriptionStatus" => isset($response["subscriptionStatus"]) ? $response["subscriptionStatus"] : "UNREGISTERED",
        "version" => isset($response["version"]) ? $response["version"] : "1.0",
        "requestId" => isset($response["requestId"]) ? $response["requestId"] : ""
    );
    
    // Log successful unsubscribe
    try {
        $myfile = fopen("unsubscribe_success.txt", "a+") or die("Unable to open file!");
        fwrite($myfile, "Success: Subscriber " . $subscriberId . " unsubscribed. Date: " . $date_ . "\n");
        fclose($myfile);
    } catch (Exception $e) {
        // Silent fail
    }
    
    echo json_encode($successResponse);
} else {
    // Failed to unsubscribe
    $failureResponse = array(
        "statusCode" => isset($response["statusCode"]) ? $response["statusCode"] : "E1003",
        "statusDetail" => isset($response["statusDetail"]) ? $response["statusDetail"] : "Unsubscribe failed",
        "subscriptionStatus" => isset($response["subscriptionStatus"]) ? $response["subscriptionStatus"] : "ERROR"
    );
    
    // Log failed unsubscribe
    try {
        $myfile = fopen("unsubscribe_failures.txt", "a+") or die("Unable to open file!");
        fwrite($myfile, "Failure: Subscriber " . $subscriberId . " - " . $failureResponse["statusDetail"] . " Date: " . $date_ . "\n");
        fclose($myfile);
    } catch (Exception $e) {
        // Silent fail
    }
    
    echo json_encode($failureResponse);
}

// Close cURL session
curl_close($ch);

?>
