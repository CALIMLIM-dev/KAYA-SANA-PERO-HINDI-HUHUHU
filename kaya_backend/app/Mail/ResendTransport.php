<?php

namespace App\Mail;

use Resend;
use Symfony\Component\Mailer\SentMessage;
use Symfony\Component\Mailer\Transport\AbstractTransport;
use Symfony\Component\Mime\MessageConverter;

class ResendTransport extends AbstractTransport
{
    protected function doSend(SentMessage $message): void
    {
        $email = MessageConverter::toEmail($message->getOriginalMessage());
        
        $resend = Resend::client(config('services.resend.key'));

        $resend->emails->send([
            'from' => $email->getFrom()[0]->getAddress(),
            'to' => collect($email->getTo())->map(fn($to) => $to->getAddress())->toArray(),
            'subject' => $email->getSubject(),
            'html' => $email->getHtmlBody(),
        ]);
    }

    public function __toString(): string
    {
        return 'resend';
    }
}
