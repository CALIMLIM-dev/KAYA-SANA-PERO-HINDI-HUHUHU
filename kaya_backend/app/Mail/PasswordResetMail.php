<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class PasswordResetMail extends Mailable
{
    use Queueable, SerializesModels;

    public string $userName;
    public string $resetCode;

    public function __construct(string $userName, string $resetCode)
    {
        $this->userName = $userName;
        $this->resetCode = $resetCode;
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            // Never the code: a subject shows on a locked phone.
            subject: 'KAYA - Reset your password',
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.password-reset',
        );
    }

    public function attachments(): array
    {
        return [];
    }
}
