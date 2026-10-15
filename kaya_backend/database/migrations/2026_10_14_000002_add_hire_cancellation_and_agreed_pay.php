<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A hire can end before the work does, and the pay can be agreed.

    applications
        cancel_requested_by / _at / _reason / _note
                        one side asking to cancel the hire, and why
        cancel_outcome  how it ended: agreed, before_start, unavailable
                        (the other side was suspended or gone), or one_sided
                        (the other side did not answer in time)
        cancelled_at    when the hire became 'cancelled'
        disputed_at     the side that did not confirm said the work did not
                        happen; settling waits for an administrator

    schedule_proposals
        pay_centavos    the pay both agreed in the chat, beside the day. KAYA
                        holds no money; this is the record a dispute reads.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('applications', function (Blueprint $table) {
            $table->foreignId('cancel_requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('cancel_requested_at')->nullable();
            $table->string('cancel_reason', 20)->nullable();
            $table->string('cancel_note', 280)->nullable();
            $table->string('cancel_outcome', 20)->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('disputed_at')->nullable();
        });

        Schema::table('schedule_proposals', function (Blueprint $table) {
            $table->unsignedInteger('pay_centavos')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('schedule_proposals', fn (Blueprint $t) => $t->dropColumn('pay_centavos'));
        Schema::table('applications', function (Blueprint $table) {
            $table->dropConstrainedForeignId('cancel_requested_by');
            $table->dropColumn(['cancel_requested_at', 'cancel_reason', 'cancel_note', 'cancel_outcome', 'cancelled_at', 'disputed_at']);
        });
    }
};
