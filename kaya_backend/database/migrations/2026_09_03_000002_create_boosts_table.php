<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Paid placement, for a job post or a worker profile.

    `jobs_posts.is_urgent` has existed since July as a free self-declared flag.
    The post-job screen tells the employer that urgent jobs "get priority
    placement and appear at the top of search results", and that has never been
    true: the column appears in no orderBy anywhere in the application. Every
    feed is ordered by recency. It is the clearest case of the inert control the
    project's own rules forbid.

    Rather than add a second, separately-priced boost beside it, this table is
    the one mechanism and is_urgent becomes the label of an active one.

    Polymorphic because both sides of the marketplace buy the same thing. A job
    post competing for workers and a worker profile competing for employers are
    the same purchase in opposite directions, and giving each its own table
    would mean writing the ranking twice.

    Windowed rather than flagged. A boolean would need a scheduled job to switch
    it off and would be wrong for as long as that job was late; a row that knows
    when it started and when it ends is simply not active outside those dates,
    with nothing to run and nothing to go stale.

    The credit transaction that paid for it is recorded so a refund knows what
    to reverse without searching the ledger by shape - the same link
    applications and invitations already carry.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('boosts', function (Blueprint $table) {
            $table->id();

            // 'job' or 'worker'. Kept as a short string rather than a morph
            // class name so the value stays readable in the database and does
            // not break if a model is ever moved between namespaces.
            $table->string('boostable_type', 16);
            $table->unsignedBigInteger('boostable_id');

            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            /*
                dateTime, not timestamp.

                Two TIMESTAMP NOT NULL columns in one table is a MySQL trap:
                with explicit_defaults_for_timestamp off, the first column
                silently gets DEFAULT CURRENT_TIMESTAMP and the second is
                left with the zero date, which strict mode then refuses -
                "Invalid default value for 'ends_at'", and the table is never
                created.

                SQLite has no such rule, so the whole test suite passed and
                this only appeared on the live MySQL server. DATETIME carries
                no implicit default at all, which is what these columns want:
                both values are always written explicitly by BoostService.
            */
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');

            // No foreign key, matching credit_transactions' own reference
            // columns: the ledger is append-only and must outlive anything it
            // paid for.
            $table->unsignedBigInteger('credit_transaction_id')->nullable();

            $table->timestamps();

            /*
                The index the feed actually uses.

                Ordering asks "is there a live boost for this row right now",
                which is a lookup on the target plus a window test. Leading with
                the target and ending with the dates lets one index answer it.
            */
            $table->index(
                ['boostable_type', 'boostable_id', 'starts_at', 'ends_at'],
                'boosts_active_lookup'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('boosts');
    }
};
