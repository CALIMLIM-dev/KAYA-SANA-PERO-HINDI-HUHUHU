<?php

namespace App\Console\Commands;

use App\Mail\VerificationCodeMail;
use App\Services\SmsSender;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Sends one test email and one test text, before anybody is watching.
 *
 * Forgot password and the verification codes only work when the mail
 * account and the SMS sender in .env do. This checks both in one go, so a
 * wrong app password or a phone that is off shows up here, not in front of
 * the panel.
 *
 *     php artisan kaya:test-contact someone@gmail.com
 *     php artisan kaya:test-contact someone@gmail.com 09171234567
 */
class TestContact extends Command
{
    protected $signature = 'kaya:test-contact
        {email : Where to send the test email}
        {phone? : Where to send the test text}';

    protected $description = 'Send a test email and a test SMS with the current settings';

    public function handle(SmsSender $sms): int
    {
        $ok = true;

        try {
            Mail::to($this->argument('email'))->send(new VerificationCodeMail('KAYA Test', '123456', 'email address'));
            $this->info('Email sent with ' . config('mail.default') . ' from ' . config('mail.from.address') . '.');
        } catch (Throwable $e) {
            $ok = false;
            $this->error('Email failed: ' . $e->getMessage());
        }

        $phone = $this->argument('phone');
        if ($phone === null) {
            return $ok ? self::SUCCESS : self::FAILURE;
        }

        if (! $sms->isConfigured()) {
            $this->error('SMS is off: set TEXTBEE_API_KEY in .env, then php artisan config:clear.');

            return self::FAILURE;
        }

        try {
            $sms->send($phone, 'KAYA test message. Your SMS codes are working.');
            $this->info('Text sent through ' . (filled(config('services.textbee.key')) ? 'textbee' : 'Semaphore') . '.');
        } catch (Throwable $e) {
            $ok = false;
            $this->error('Text failed: ' . $e->getMessage());
        }

        return $ok ? self::SUCCESS : self::FAILURE;
    }
}
