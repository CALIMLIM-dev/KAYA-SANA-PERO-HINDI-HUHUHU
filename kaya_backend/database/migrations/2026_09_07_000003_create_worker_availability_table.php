<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    When a worker can actually work.

    The only availability that existed was a single Available/Busy flag the
    worker sets by hand, which answers nothing an employer needs: somebody
    "available" might only ever be free on Sundays. This is the recurring
    pattern - the days of the week, and roughly when on those days.

    Periods rather than exact times, deliberately. A tradesperson says "I can
    do weekends and weekday mornings", not "08:00 to 12:00", and a time picker
    for fourteen values is a form nobody finishes. Four periods cover how the
    work is actually described and still filter cleanly.

    What is NOT here is the jobs they are already booked on. That is derived
    from accepted and completed applications whenever anybody asks - a second
    copy of "what is this worker doing" would drift from the first, which is
    exactly what happened to the conversation job_id and the application
    tally.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('worker_availability')) {
            return;
        }

        Schema::create('worker_availability', function (Blueprint $table) {
            $table->id();

            // Keyed to the user, like every other worker-side table here, so
            // it survives a profile row being rebuilt.
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');

            // 0 = Sunday, matching Carbon's dayOfWeek so nothing has to
            // translate between the two.
            $table->unsignedTinyInteger('day_of_week');

            $table->enum('period', ['morning', 'afternoon', 'evening', 'whole_day']);

            $table->timestamps();

            // One row per day per period: saving the same pattern twice is a
            // normal thing for a form to do, and it must not double up.
            $table->unique(['user_id', 'day_of_week', 'period']);

            // The filter asks "who is free on a Saturday", which is this.
            $table->index(['day_of_week', 'period']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('worker_availability');
    }
};
