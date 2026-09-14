<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A review an administrator took down.

    Hidden, not deleted: the row stays so the log can point at it and the
    reviewer cannot write another for the same job. It leaves every public
    list and the rating average the moment it is hidden.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reviews', function (Blueprint $table) {
            $table->timestamp('hidden_at')->nullable()->after('tags');
            $table->string('hidden_reason')->nullable()->after('hidden_at');
            $table->foreignId('hidden_by')->nullable()->after('hidden_reason')
                ->constrained('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('reviews', function (Blueprint $table) {
            $table->dropConstrainedForeignId('hidden_by');
            $table->dropColumn(['hidden_at', 'hidden_reason']);
        });
    }
};
