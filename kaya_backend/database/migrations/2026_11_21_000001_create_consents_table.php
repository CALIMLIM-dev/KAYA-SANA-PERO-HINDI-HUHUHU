<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Proof that somebody agreed before sending something sensitive: their ID
    and selfie, a business document, a certificate or a license. One row per
    upload, with the version of the Terms they were shown.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('consents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('subject', 40);
            $table->string('terms_version', 40);
            $table->timestamp('created_at')->useCurrent();
            $table->index(['user_id', 'subject']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('consents');
    }
};
