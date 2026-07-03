<?php 

ini_set('error_log', 'ussd-app-error.log');
require 'bdapps_cass_sdk.php';
date_default_timezone_set('Asia/Dhaka');

$appid = "APP_128956";
$apppassword = "a0b6805ae4de029d93def2a16d633b4a";
$logger = new Logger();

function readSMSNotification() {
    global $appid, $apppassword, $logger;

    $body = file_get_contents('php://input');
    $response = json_decode($body);

    // Logging the full response body for debugging
    file_put_contents("FSubNoti.txt", date("Y-m-d h:i:sa") . "\n" . $body . "\n", FILE_APPEND);

    // Ensure all required properties exist
    if (!isset($response->status) || !isset($response->subscriberId)) {
        file_put_contents("FuncSubNoti.txt", "Invalid response structure\n", FILE_APPEND);
        return;
    }

    $status = $response->status;
    $subscriberId = $response->subscriberId;

    // Only send SMS if status is REGISTERED
    if (strtoupper($status) == "REGISTERED") {
        try {
            $sender = new SmsSender("https://developer.bdapps.com/sms/send", $appid, $apppassword);

            // This is the address to send SMS to
            $address = $subscriberId;

            // Your app download link
            $message = "BMIc-তে সাবস্ক্রাইব করার জন্য ধন্যবাদ! অ্যাপটি ডাউনলোড করতে ক্লিক করুন: https://shorturl.at/G2D8Y";

            $response = $sender->sms($message, $address);

            // Logging response
            file_put_contents("res.txt", print_r($response, true), FILE_APPEND);
            file_put_contents("report.txt", date("Y-m-d H:i:s") . " , Sent to: " . $address . " , Message: " . $message . "\n", FILE_APPEND);

        } catch (SMSServiceException $e) {
            $logger->WriteLog($e->getErrorCode() . " " . $e->getErrorMessage() . "\n");
        }
    }

    // Log all received notifications
    $log = "TimeStamp: {$response->timeStamp} | Status: {$status} | App Id: {$response->applicationId} | SubscriberId: {$subscriberId}\n";
    file_put_contents("FuncSubNoti.txt", $log, FILE_APPEND);
}

readSMSNotification();

?>