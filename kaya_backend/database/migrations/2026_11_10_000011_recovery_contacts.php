<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Email and phone as recovery contacts.

    pending_phone: a new number waits here until a code sent to it comes
    back, so a confirmed recovery number is never swapped without one.

    Google accounts: Google confirmed the address before handing it over,
    so those emails count as confirmed.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('pending_phone', 30)->nullable()->after('phone');
        });

        DB::table('users')
            ->whereNotNull('google_id')
            ->whereNotNull('email')
            ->whereNull('email_verified_at')
            ->update(['email_verified_at' => now()]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('pending_phone');
        });
    }
};
