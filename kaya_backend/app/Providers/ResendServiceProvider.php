<?php

namespace App\Providers;

use App\Mail\ResendTransport;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\ServiceProvider;

class ResendServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        Mail::extend('resend', function () {
            return new ResendTransport();
        });
    }
}
