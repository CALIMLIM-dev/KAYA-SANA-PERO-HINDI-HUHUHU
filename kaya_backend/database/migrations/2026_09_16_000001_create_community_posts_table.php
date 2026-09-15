<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Community posts: a worker offering their services, or a business
    looking for people, on a board that is not the job feed.

    The job feed is one employer, one piece of work, applications and a
    hire. This is the notice board beside it: "Mason available in Urdaneta,
    weekdays" and "Hiring five painters for a subdivision, start Monday".
    One table with a type rather than two, so there is one price path, one
    moderation queue and one expiry rule.

    A post runs for a fixed number of days and is paid for up front, which
    is what keeps the board from filling with stale notices. It ends by the
    clock, or when the poster takes it down, or when an administrator
    removes it - and it is never deleted, so a report can still point at
    what was said.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 20);                 // worker | business
            $table->foreignId('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('title', 80);
            $table->text('body');
            $table->string('photo_path')->nullable();
            $table->string('location')->nullable();
            $table->foreignId('location_id')->nullable()->constrained('locations')->nullOnDelete();
            $table->string('status', 20)->default('live'); // live | ended | removed
            $table->timestamp('expires_at');
            $table->unsignedBigInteger('credit_transaction_id')->nullable();
            $table->string('removed_reason')->nullable();
            $table->foreignId('removed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['status', 'expires_at']);
            $table->index(['type', 'status']);
            $table->index('user_id');
        });

        /*
            A conversation without a job.

            Every thread so far began with a hire, so job_id was required.
            Answering a community post starts a thread with no job behind it,
            and the column has to allow that. Everything that reads job_id
            already tolerates null: the inbox falls back to a plain label and
            the chat hides the job card and the schedule button.
        */
        Schema::table('conversations', function (Blueprint $table) {
            $table->dropForeign(['job_id']);
        });

        Schema::table('conversations', function (Blueprint $table) {
            $table->foreignId('job_id')->nullable()->change();
            $table->foreign('job_id')->references('id')->on('jobs_posts')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_posts');
    }
};
