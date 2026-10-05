<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    PayMongo is gone, and this table only ever logged its webhooks. Top-ups
    are free while the app is in testing; Google Play Billing comes later.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('credit_webhook_events');
    }

    public function down(): void
    {
        Schema::create('credit_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 20);
            $table->string('provider_event_id');
            $table->string('event_type', 60);
            $table->json('payload');
            $table->timestamp('received_at');
            $table->timestamps();

            $table->unique(['provider', 'provider_event_id'], 'credit_webhook_events_unique');
        });
    }
};
