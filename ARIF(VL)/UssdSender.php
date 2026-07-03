<?php

namespace App\Classes;
use Exception;
use App\Classes\Core;



class UssdSender extends Core{
        private $applicationId,
            $password,
            $charging_amount='',
            $encoding='',
            $version='',
            $deliveryStatusRequest='',
            $binaryHeader='',
            $sourceAddress='',
            $serverURL;

    public function __construct($server,$applicationId,$password){
        $this->serverURL = $server; 
        $this->applicationId = $applicationId; 
        $this->password = $password; 
    }

    public function ussd( $sessionId, $message, $destinationAddress, $ussdOperation='mo-cont'){
                         
        if (is_array($destinationAddress)) { 
            return $this->ussdMany($message,$sessionId, $ussdOperation, $destinationAddress);
                
        } else if (is_string($destinationAddress) && trim($destinationAddress) != "") {
            return $this->ussdMany($message,$sessionId, $ussdOperation, $destinationAddress);
        } else {
            throw new Exception("address should a string or a array of strings");
        }
    }

    private function ussdMany($message,$sessionId, $ussdOperation, $destinationAddress)
    {

        $arrayField = array("applicationId" => $this->applicationId,
            "password" => $this->password,
            "message" => $message,
            "destinationAddress" => $destinationAddress,
            "sessionId" => $sessionId,
            "ussdOperation" => $ussdOperation,
            "encoding" => "440"
            );

        $jsonObjectFields = json_encode($arrayField);
        return $this->sendRequest($jsonObjectFields,$this->serverURL);
    }

    private function handleResponse($resp){
        if ($resp == "") {
            throw new UssdException
            ("Server URL is invalid", '500');
        } else {
            echo $resp;
        }
    }

}