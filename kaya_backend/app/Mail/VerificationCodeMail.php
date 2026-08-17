<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * The code that verifies a contact detail.
 *
 * Shaped like PasswordResetMail, which already works through Resend, rather
 * than introducing a second way of sending mail.
 */
class VerificationCodeMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $userName,
        public string $code,
        /** What is being verified, e.g. "email address". Used in the copy. */
        public string $subjectOfVerification,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'KAYA - Your verification code');
    }

    public function content(): Content
    {
        return new Content(view: 'emails.verification-code');
    }

    public function attachments(): array
    {
        return [];
    }
}
