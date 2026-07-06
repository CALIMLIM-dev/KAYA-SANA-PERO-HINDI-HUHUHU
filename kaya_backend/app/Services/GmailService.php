w<?php

namespace App\Services;

use Google\Client;
use Google\Service\Gmail;
use Google\Service\Gmail\Message;

class GmailService
{
    private $client;
    private $service;

    public function __construct()
    {
        $this->client = new Client();
        $this->client->setApplicationName('KAYA');
        $this->client->setScopes([Gmail::GMAIL_SEND]);
        $this->client->setAuthConfig(base_path('client_secret_217067120890-b5p9b0lkath30n40ph3ii14gamnk1oom.apps.googleusercontent.com.json'));
        $this->client->setAccessType('offline');
        
        $this->service = new Gmail($this->client);
    }

    public function sendEmail($to, $subject, $body)
    {
        $message = new Message();
        
        $rawMessage = "From: KAYA <noreply@kaya.com>\r\n";
        $rawMessage .= "To: {$to}\r\n";
        $rawMessage .= "Subject: {$subject}\r\n";
        $rawMessage .= "MIME-Version: 1.0\r\n";
        $rawMessage .= "Content-type: text/html; charset=iso-8859-1\r\n\r\n";
        $rawMessage .= $body;
        
        $message->setRaw(base64_encode($rawMessage));
        
        return $this->service->users_messages->send('me', $message);
    }
}
