<?php

$user_mobile = $_POST['user_mobile'] ?? "01897776680";
$user_mobile="tel:88".$user_mobile;
file_put_contents("user_number.txt",$user_mobile);

// Request data
$requestData = array(
    "applicationId" => "APP_139127",
    "password" => "9ec9c4e178415f454fa599e5990430cc",
    "subscriberId" => "$user_mobile",
    "applicationHash" => "VenueLock",
    "applicationMetaData" => array(
        "client" => "MOBILEAPP",
        "device" => "Android",
        "os" => "Android",
        "appCode" => "VenueLock"
    )
);

// Convert request data to JSON
$requestJson = json_encode($requestData);

// cURL options
$url = "https://developer.bdapps.com/subscription/otp/request";  // Replace with actual API endpoint URL
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
if ($responseJson === false) {
    echo "cURL error: " . curl_error($ch);
} else {
    $response = json_decode($responseJson, true);
    if ($response === null) {
        echo "Invalid JSON in response: " . $responseJson;
        
        $referenceNo = array('referenceNo'=> $response["referenceNo"]);
        echo json_encode($referenceNo);
    } else {
        // Handle response
        // echo "Status code: " . $response["statusCode"] . "\n";
        // echo "Status detail: " . $response["statusDetail"] . "\n";
        // echo "Reference number: " . $response["referenceNo"] . "\n";
        // echo "Version: " . $response["version"] . "\n";
        
        $referenceNo = array('referenceNo'=> $response["referenceNo"]);
        echo json_encode($referenceNo);
    }
}

// Close cURL session
curl_close($ch);

?>
