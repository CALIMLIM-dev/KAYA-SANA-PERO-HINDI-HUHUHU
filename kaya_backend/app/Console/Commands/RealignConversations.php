<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Conversation;
use Illuminate\Console\Command;

/*
    Points every conversation at its newest hire.

    A thread is one per pair of people, and employer_id and worker_id say
    who is hiring whom now. Every hire path rewrites them today, but
    threads made before that rule kept the seats of their first hire. Two
    hybrids who hired each other both ways could see "You hired" on a
    thread where the other person hired them. This sets the seats and the
    job from the newest accepted or completed application between the two,
    and leaves threads that never had a hire alone.
*/
class RealignConversations extends Command
{
    protected $signature = 'kaya:realign-conversations {--dry-run : Report without writing}';

    protected $description = 'Set each conversation\'s employer, worker and job from its newest hire';

    public function handle(): int
    {
        $changed = 0;

        Conversation::query()->orderBy('id')->chunkById(200, function ($conversations) use (&$changed) {
            foreach ($conversations as $conversation) {
                $a = (int) $conversation->pair_low;
                $b = (int) $conversation->pair_high;

                $hire = Application::query()
                    ->whereIn('status', ['accepted', 'completed'])
                    ->where(function ($q) use ($a, $b) {
                        $q->where(fn ($w) => $w->where('worker_id', $a)->whereHas('job', fn ($j) => $j->where('employer_id', $b)))
                          ->orWhere(fn ($w) => $w->where('worker_id', $b)->whereHas('job', fn ($j) => $j->where('employer_id', $a)));
                    })
                    ->with('job:id,employer_id')
                    ->orderByDesc('id')
                    ->first();

                if ($hire === null || $hire->job === null) {
                    continue;
                }

                $employerId = (int) $hire->job->employer_id;
                $workerId = (int) $hire->worker_id;

                if ((int) $conversation->employer_id === $employerId
                    && (int) $conversation->worker_id === $workerId
                    && (int) $conversation->job_id === (int) $hire->job_id) {
                    continue;
                }

                $changed++;
                $this->line(sprintf(
                    '  #%d: employer %d -> %d, worker %d -> %d, job %s -> %d',
                    $conversation->id,
                    $conversation->employer_id, $employerId,
                    $conversation->worker_id, $workerId,
                    $conversation->job_id ?? 'none', $hire->job_id,
                ));

                if (! $this->option('dry-run')) {
                    $conversation->update([
                        'employer_id' => $employerId,
                        'worker_id'   => $workerId,
                        'job_id'      => $hire->job_id,
                    ]);
                }
            }
        });

        $this->info($this->option('dry-run')
            ? "  {$changed} would change."
            : "  {$changed} realigned.");

        return self::SUCCESS;
    }
}
