<?php 

ini_set('error_log', 'ussd-app-error.log');
require 'bdapps_cass_sdk.php';
date_default_timezone_set('Asia/Dhaka');

$appid = "APP_139127";
$apppassword = "9ec9c4e178415f454fa599e5990430cc";

// Direct APK download used in the subscription response SMS. Must be a
// working link on a real host — bdapps rejects Drive/GitHub links. Note the
// parentheses in the ARIF(VL) path are legal in a URL but some SMS clients
// stop auto-linking at them; a paren-free path is safer if one is available.
const VENUELOCK_APK_URL = "https://ruetandroiddevelopers.com/ARIF(VL)/VenueLock.apk";

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

            // bdapps requires this message to name the app, state its
            // category, and carry a working direct APK link (Drive/GitHub
            // links are rejected). Keep it in sync with the submitted FAQ.
            $message = "VenueLock (Events) — সাবস্ক্রাইব করার জন্য ধন্যবাদ! "
                . "আসন-ভিত্তিক বুকিং ও QR এন্ট্রি পাস। অ্যাপটি ডাউনলোড করুন: "
                . VENUELOCK_APK_URL;

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