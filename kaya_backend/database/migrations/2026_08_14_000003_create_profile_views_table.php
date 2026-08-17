<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Who looked at whose profile.

    Nothing counted views before this. A worker could complete their profile,
    upload an ID and wait, with no way to tell whether anyone was looking —
    which is the difference between "nobody wants me" and "I am invisible", and
    the app gave them no way to distinguish the two. Seeing "8 employers viewed
    your profile this week" is the reason to open the app tomorrow.

    It is also the measuring stick every paid feature later depends on. Selling
    a profile boost without a view count means charging for a result nobody can
    check.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('profile_views', function (Blueprint $table) {
            $table->id();

            $table->foreignId('viewer_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('viewed_id')->constrained('users')->cascadeOnDelete();

            /*
                Which side of the marketplace was being looked at.

                A hybrid account has both a worker and an employer profile, so
                "someone viewed you" is ambiguous without this — the worker's
                view count must not be inflated by people reading their company
                page.
            */
            $table->string('viewed_as', 10)->default('worker');

            // Where the view came from: browse, search, application, invitation.
            // Kept for analytics later; nothing branches on it yet.
            $table->string('source', 20)->nullable();

            /*
                The date, stored separately from created_at.

                Deduplication is per viewer per day: an employer who opens the
                same profile five times while deciding is one interested party,
                not five. Without that the count measures indecision and stops
                meaning anything.

                A plain date column plus the unique index below makes the
                database enforce it, so a race between two simultaneous requests
                cannot slip a duplicate through — which a read-then-write check
                in PHP would eventually allow.
            */
            $table->date('viewed_on');

            $table->timestamps();

            $table->unique(
                ['viewer_id', 'viewed_id', 'viewed_as', 'viewed_on'],
                'profile_views_daily_unique'
            );

            // "Who viewed me recently" — the only query the app makes.
            $table->index(['viewed_id', 'viewed_as', 'viewed_on'], 'profile_views_recent_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('profile_views');
    }
};
