<?php

$date_= date("Y-m-d h:i:sa");

$user_otp = $_POST['Otp'];
$referenceNo = $_POST['referenceNo'];


try{
    $myfile = fopen("OTP+RefNo.txt", "a+") or die("Unable to open file!");
    fwrite($myfile,"OTP:".$user_otp." RefNo:".$referenceNo." Date".$date_."\n");
}
catch(Exception $e){
    
}
  
  
// Request data
$requestData = array(
    "applicationId" => "APP_139127",
    "password" => "9ec9c4e178415f454fa599e5990430cc",
    "referenceNo" => "$referenceNo",
    "otp" => "$user_otp"
);

// Convert request data to JSON
$requestJson = json_encode($requestData);

// cURL options
$url = "https://developer.bdapps.com/subscription/otp/verify";  // Replace with actual API endpoint URL
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
    } else {
        // Handle response
        // echo "Status code: " . $response["statusCode"] . "\n";
        // echo "Status detail: " . $response["statusDetail"] . "\n";
        // echo "Subscriber ID: " . $response["subscriberId"] . "\n";
        // echo "Subscription status: " . $response["subscriptionStatus"] . "\n";
        // echo "Version: " . $response["version"] . "\n";
        
        $subscriptionStatus = array('subscriptionStatus'=> $response["subscriptionStatus"]);
        echo json_encode($subscriptionStatus);
    }
}

// Close cURL session
curl_close($ch);

?>
