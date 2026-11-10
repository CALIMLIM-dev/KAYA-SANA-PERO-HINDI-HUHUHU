<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/*
    "Your password was changed." / "Your phone number was changed."

    Sent to the address on the account after something that could lock its
    owner out, so a change they did not make does not go unnoticed.
*/
class AccountNoticeMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $userName,
        public string $heading,
        public string $body,
        public string $when,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: "KAYA - {$this->heading}");
    }

    public function content(): Content
    {
        return new Content(view: 'emails.account-notice');
    }
}
