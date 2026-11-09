<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    The reported person is no longer told a report was filed, and the
    screen those notices opened is gone. The old ones would open nothing.
*/
return new class extends Migration
{
    public function up(): void
    {
        DB::table('user_notifications')->whereIn('type', ['report.filed', 'report.closed'])->delete();
    }

    public function down(): void
    {
    }
};
