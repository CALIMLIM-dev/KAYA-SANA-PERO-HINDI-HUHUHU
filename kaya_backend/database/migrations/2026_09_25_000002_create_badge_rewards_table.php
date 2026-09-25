<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    What has already been paid out for a badge.

    Badges themselves stay derived - BadgeService reads the record every time
    it is asked, which is why a rating that falls below 4.5 loses "Highly
    Rated" instead of keeping it forever. Nothing here changes that.

    This table is not a copy of the badges. It is the receipt: a payment was
    made, on this date, for this badge, and here is the ledger line. Without
    it the first Barya reward would be paid again on every read, and with a
    stored badge instead the badge and the record would drift the way the
    conversation job_id and the application count both did.

    One row per person per badge, ever. Losing a badge and earning it back
    pays nothing the second time: the reward is for reaching it, and paying
    for a rating that oscillates around 4.5 would be a tap anybody with five
    reviews could turn on.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('badge_rewards', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();

            // The badge's own code, as BadgeService returns it: 'first_job',
            // 'jobs_10', 'highly_rated' and so on.
            $table->string('code', 40);

            // Which side of a hybrid account earned it. The same account can
            // finish its first job and make its first hire, and those are two
            // achievements rather than one.
            $table->string('side', 10);

            $table->unsignedInteger('amount');

            $table->foreignId('credit_transaction_id')->nullable()
                ->constrained('credit_transactions')->nullOnDelete();

            $table->timestamps();

            // Paid once, ever. The unique key is the guarantee, not the check
            // in the service - two requests arriving together would both pass
            // a read and only one can win here.
            $table->unique(['user_id', 'code', 'side']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('badge_rewards');
    }
};
