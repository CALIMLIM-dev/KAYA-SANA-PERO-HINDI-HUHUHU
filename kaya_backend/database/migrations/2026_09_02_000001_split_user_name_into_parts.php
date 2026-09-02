<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    A Philippine name is four fields, not one string.

    `users.name` has always been a single column, so a worker could not record
    a middle name (which here is the mother's maiden surname and appears on
    every government ID they upload for verification) or a suffix, and an
    employer reading an applicant list had no reliable way to sort or address
    anyone. Matching a profile against the ID photo beside it was a judgement
    call rather than a comparison.

    ADDED, NOT REPLACED. `name` stays, and stays the display value every
    existing reader already uses - job cards, chat, applicant lists, reviews,
    notifications, search and the whole admin panel read it today. Dropping it
    would mean changing every one of those in the same commit, which is the
    version of this change that breaks a demo. The parts become the source of
    truth and `name` is kept in step by the model (see User::booted), so
    readers can move across one at a time, or never.

    The backfill is a best-effort split of what is already there: one word is a
    first name, two are first and last, three or more take the last word as the
    surname and everything between as the middle. It will get some names wrong
    - Philippine surnames are frequently two words ("Dela Cruz", "San Juan") -
    which is why the parts are nullable and editable rather than trusted. What
    it must never do is lose the original, and it does not: `name` is
    untouched, so a bad split shows a tidy display name over parts the person
    can correct.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('first_name', 100)->nullable()->after('name');
            $table->string('middle_name', 100)->nullable()->after('first_name');
            $table->string('last_name', 100)->nullable()->after('middle_name');
            // Jr., Sr., III. Short on purpose - a long value here is a sign
            // something else was typed into the wrong box.
            $table->string('suffix', 20)->nullable()->after('last_name');
        });

        $this->backfill();
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['first_name', 'middle_name', 'last_name', 'suffix']);
        });
    }

    /*
        Chunked, and skips anyone already split.

        Written with the query builder rather than the model so it cannot fire
        User::booted and rewrite `name` from the parts it is in the middle of
        guessing - the whole point is that `name` survives this untouched.
    */
    private function backfill(): void
    {
        DB::table('users')
            ->select('id', 'name')
            ->whereNull('first_name')
            ->orderBy('id')
            ->chunkById(500, function ($rows) {
                foreach ($rows as $row) {
                    $parts = preg_split('/\s+/', trim((string) $row->name), -1, PREG_SPLIT_NO_EMPTY) ?: [];

                    if ($parts === []) {
                        continue;
                    }

                    $first = array_shift($parts);
                    $last = $parts === [] ? null : array_pop($parts);
                    $middle = $parts === [] ? null : implode(' ', $parts);

                    DB::table('users')->where('id', $row->id)->update([
                        'first_name'  => mb_substr($first, 0, 100),
                        'middle_name' => $middle === null ? null : mb_substr($middle, 0, 100),
                        'last_name'   => $last === null ? null : mb_substr($last, 0, 100),
                    ]);
                }
            });
    }
};
