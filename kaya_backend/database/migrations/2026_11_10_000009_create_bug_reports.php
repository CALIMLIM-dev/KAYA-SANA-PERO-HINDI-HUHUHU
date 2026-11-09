<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Something's Broken, from KAYA Assistant's menu.

    What the person picked and wrote, an optional screenshot, and what KAYA
    adds without asking them anything technical: the app version, the phone,
    and any server errors on their account in the minutes before. Fixed sends
    them a notification.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bug_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('issue', 60);
            $table->string('screen', 30);
            $table->text('details')->nullable();
            $table->string('screenshot_path')->nullable();
            $table->string('app_version', 20)->nullable();
            $table->string('device', 120)->nullable();
            $table->json('server_error_ids')->nullable();
            $table->string('status', 10)->default('new');
            $table->dateTime('fixed_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bug_reports');
    }
};
