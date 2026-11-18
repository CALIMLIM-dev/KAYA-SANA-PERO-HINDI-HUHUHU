<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Leaving a support chat used to delete it. Now it is hidden from the
    person and kept for the team, so an appeal or a banned person's support
    chat still shows on admin what they and KAYA Assistant said.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_messages', function (Blueprint $table) {
            $table->timestamp('hidden_at')->nullable()->after('read_at');
        });
    }

    public function down(): void
    {
        Schema::table('support_messages', function (Blueprint $table) {
            $table->dropColumn('hidden_at');
        });
    }
};
