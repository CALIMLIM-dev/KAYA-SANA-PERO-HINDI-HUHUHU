<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A time for the work, agreed by both people.

    The job post says when the work runs - a start date and how long it takes.
    That is the employer's statement, made before anybody was hired. It is not
    the same fact as "you and I settled on Saturday morning", which is a thing
    two named people agree after they are talking, and which either of them can
    refuse.

    So it lives with the conversation, because that is where the agreeing
    happens, and it is a proposal with an answer rather than a field somebody
    fills in. One side offers a day, the other accepts or declines; declining
    is a real outcome, not an error, and the counter-offer is just the next
    proposal.

    Nothing here duplicates the job's dates. The post says the work is that
    week; this says the two of them meet on the Saturday of it.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('schedule_proposals')) {
            return;
        }

        Schema::create('schedule_proposals', function (Blueprint $table) {
            $table->id();

            $table->foreignId('conversation_id')->constrained('conversations')->onDelete('cascade');

            // The job it is about. A pair has one thread across every job they
            // have done together, so the thread alone cannot say which work is
            // being scheduled.
            $table->foreignId('job_id')->nullable()->constrained('jobs_posts')->onDelete('cascade');

            $table->foreignId('proposed_by')->constrained('users')->onDelete('cascade');

            $table->date('scheduled_date');

            // The same four the rest of the app speaks in. A time picker
            // collects a precision nobody keeps; "Saturday morning" is what
            // people actually agree to.
            $table->enum('period', ['morning', 'afternoon', 'evening', 'whole_day']);

            $table->string('note', 280)->nullable();

            $table->enum('status', ['proposed', 'accepted', 'declined', 'superseded'])
                ->default('proposed');

            $table->timestamp('responded_at')->nullable();

            $table->timestamps();

            // "What is the live proposal on this thread" is the question every
            // screen asks.
            $table->index(['conversation_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('schedule_proposals');
    }
};
