<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Server errors, readable from the admin panel.

    The server logs to stderr because storage/ is owned by www-data and the
    deploy user has no sudo, and php-fpm drops that stream - so a 500 left no
    trace anyone could read. A report that failed with a 500 on 18 Oct 2026
    could not be traced for exactly that reason. One row per distinct error,
    counted, so a loop cannot fill the table.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('server_errors', function (Blueprint $table) {
            $table->id();
            // The same error from the same place is one row.
            $table->string('hash', 40)->unique();
            $table->string('exception', 255);
            $table->text('message');
            $table->string('file', 255)->nullable();
            $table->unsignedInteger('line')->nullable();
            $table->string('method', 10)->nullable();
            $table->string('url', 500)->nullable();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->text('trace')->nullable();
            $table->unsignedInteger('count')->default(1);
            // A datetime, not a timestamp: see kaya-mysql-migration-timestamps.
            $table->dateTime('last_seen_at')->nullable()->index();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('server_errors');
    }
};
