<?php

namespace App\Console\Commands;

use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\JobPost;
use Illuminate\Console\Command;

/*
    Hides the threads of work that finished before hiding existed.

    The rule is applied on the transition: JobCompletionService archives a
    thread at the moment its job reaches 'completed'. Every job that was
    already finished when that shipped never transitions again, so its thread
    stayed in both inboxes forever - the pair kept talking, which is the exact
    loophole the rule was written to close.

    The migration added the column and deliberately backfilled nothing,
    because whether to hide conversations retroactively is a decision rather
    than a schema change. This is that decision, run once.

    Safe to run again: a thread already hidden is skipped, and a pair who have
    since been rehired have a live job and are left alone.
*/
class HideFinishedConversations extends Command
{
    protected $signature = 'kaya:hide-finished-conversations {--dry-run : Count what would be hidden and change nothing}';

    protected $description = 'Hide conversations whose work finished before hiding was built';

    public function handle(): int
    {
        $dry = (bool) $this->option('dry-run');

        if ($dry) {
            $this->warn('Dry run: nothing will be changed.');
        }

        $jobs = 0;

        /*
            A thread points at the most recent job the pair touched, so the
            question is whether THAT job is over - not whether they ever
            finished anything. A pair rehired last week has a live job on the
            thread and keeps it.
        */
        Conversation::query()
            ->whereNull('archived_at')
            ->whereNotNull('job_id')
            ->with('job:id,status')
            ->chunkById(200, function ($threads) use ($dry, &$jobs) {
                foreach ($threads as $thread) {
                    if ($thread->job?->status !== 'completed') {
                        continue;
                    }

                    $jobs++;

                    if (! $dry) {
                        $thread->archive();
                    }
                }
            });

        $posts = 0;

        // The same for a board thread whose notice is no longer up.
        Conversation::query()
            ->whereNull('archived_at')
            ->whereNull('job_id')
            ->whereNotNull('community_post_id')
            ->with('communityPost:id,status,expires_at')
            ->chunkById(200, function ($threads) use ($dry, &$posts) {
                foreach ($threads as $thread) {
                    $post = $thread->communityPost;

                    if ($post === null || $post->isLive()) {
                        continue;
                    }

                    $posts++;

                    if (! $dry) {
                        $thread->archive();
                    }
                }
            });

        $this->info($dry
            ? "Would hide {$jobs} finished job threads and {$posts} ended board threads."
            : "Hid {$jobs} finished job threads and {$posts} ended board threads.");

        return self::SUCCESS;
    }
}
