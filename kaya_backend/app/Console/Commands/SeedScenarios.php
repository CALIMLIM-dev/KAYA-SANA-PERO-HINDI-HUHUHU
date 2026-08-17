<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Review;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * One ready-made situation per major feature, so each can be opened and looked
 * at without first playing the whole game to reach it.
 *
 * Reaching "both sides confirmed, employer has reviewed, worker has not" by
 * hand takes two accounts, a job, an application, an acceptance and three more
 * taps — every time you want to check that one screen. These build every such
 * state at once and print where to look.
 *
 * Everything is namespaced to @scenario.kaya.local and removed by
 * `php artisan scenarios:clear`, so it never mixes with real testing accounts.
 */
class SeedScenarios extends Command
{
    protected $signature = 'scenarios:seed';
    protected $description = 'Create one account and job per major feature state';

    private const DOMAIN = '@scenario.kaya.local';
    private const PASSWORD = 'password';

    private int $categoryId;
    private int $locationId;

    public function handle(): int
    {
        $this->categoryId = DB::table('categories')->value('id');
        $this->locationId = DB::table('locations')->whereNotNull('latitude')->value('id');

        if (! $this->categoryId || ! $this->locationId) {
            $this->error('Categories or locations are not seeded. Run the seeders first.');

            return self::FAILURE;
        }

        $this->call('scenarios:clear');

        $employer = $this->employer('boss', 'Elena Boss');
        $rows = [];

        $rows[] = $this->pendingApplicant($employer);
        $rows[] = $this->activeHire($employer);
        $rows[] = $this->waitingOnWorker($employer);
        $rows[] = $this->readyToReview($employer);
        $rows[] = $this->halfReviewed($employer);
        $rows[] = $this->repeatHire($employer);
        $rows[] = $this->pendingInvitation($employer);

        $this->newLine();
        $this->line('  Employer for every scenario below:');
        $this->line('    boss'.self::DOMAIN.'   password: '.self::PASSWORD);
        $this->newLine();
        $this->table(['Feature', 'Sign in as', 'What you should see'], $rows);
        $this->newLine();
        $this->line('  Remove it all with: php artisan scenarios:clear');

        return self::SUCCESS;
    }

    // ── the scenarios ────────────────────────────────────────────────────────

    private function pendingApplicant(User $employer): array
    {
        $worker = $this->worker('applicant', 'Ariel Applicant');
        $job = $this->job($employer, 'Repaint a gate');
        $this->apply($job, $worker);

        return [
            'Accepting an applicant',
            'boss (employer)',
            'My Activity > Active Jobs > 1 applicant, with skills and Accept',
        ];
    }

    private function activeHire(User $employer): array
    {
        $worker = $this->worker('hired', 'Hector Hired');
        $job = $this->job($employer, 'Fix a leaking roof', 'in_progress');
        $application = $this->apply($job, $worker, 'accepted');
        $conversation = $this->conversation($job, $worker);

        $this->say($conversation, $employer, 'Are you on the way?');
        $this->say($conversation, $worker, 'Yes, about 20 minutes.', read: true);
        $this->say($conversation, $employer, 'Take your time.');

        return [
            'Messaging, seen, tracking',
            'hired (worker)',
            'Chat has one unread; worker can share location and mark complete',
        ];
    }

    private function waitingOnWorker(User $employer): array
    {
        $worker = $this->worker('waiting', 'Wilma Waiting');
        $job = $this->job($employer, 'Clear a vacant lot', 'in_progress');
        $this->apply($job, $worker, 'accepted', employerDone: true);

        return [
            'Two sided completion',
            'waiting (worker)',
            '"The employer marked this done" and a Mark as complete button',
        ];
    }

    private function readyToReview(User $employer): array
    {
        $worker = $this->worker('done', 'Delia Done');
        $job = $this->job($employer, 'Install ceiling fans', 'completed');
        $this->apply($job, $worker, 'completed', employerDone: true, workerDone: true);

        return [
            'Leaving a review',
            'done (worker)',
            'Job is completed and offers Review employer; neither side has yet',
        ];
    }

    private function halfReviewed(User $employer): array
    {
        $worker = $this->worker('half', 'Hana Halfway');
        $job = $this->job($employer, 'Tile a bathroom', 'completed');
        $this->apply($job, $worker, 'completed', employerDone: true, workerDone: true);

        // Employer has reviewed; the worker has not. This is the state that
        // proves the withholding rule — the worker is told a review exists but
        // cannot read it until they write their own.
        $this->review($employer, $worker, $job, 5, 'Fast and tidy.', 'worker');

        return [
            'Review withheld until reciprocated',
            'half (worker)',
            '"They reviewed you" but the text stays hidden until you review back',
        ];
    }

    private function repeatHire(User $employer): array
    {
        $worker = $this->worker('regular', 'Ramon Regular');

        // Two finished jobs already, plus a live application on a third.
        foreach (['Rewire a socket', 'Replace a light switch'] as $title) {
            $past = $this->job($employer, $title, 'completed');
            $this->apply($past, $worker, 'completed', employerDone: true, workerDone: true);
        }

        $current = $this->job($employer, 'Rewire the kitchen');
        $this->apply($current, $worker, 'pending');

        return [
            'Rehire badge',
            'boss (employer)',
            'Applicants on "Rewire the kitchen" show Ramon with "Hired 2x"',
        ];
    }

    private function pendingInvitation(User $employer): array
    {
        $worker = $this->worker('invited', 'Ivy Invited');
        $job = $this->job($employer, 'Weekend garden clearing');

        Invitation::create([
            'job_id' => $job->id,
            'employer_id' => $employer->id,
            'worker_id' => $worker->id,
            'status' => 'pending',
        ]);

        return [
            'Invitations',
            'invited (worker)',
            'One pending invitation that can be accepted or declined',
        ];
    }

    // ── builders ─────────────────────────────────────────────────────────────

    private function account(string $handle, string $name): User
    {
        return User::create([
            'name' => $name,
            'email' => $handle.self::DOMAIN,
            'password' => Hash::make(self::PASSWORD),
            'terms_accepted' => true,
            'terms_accepted_at' => now(),
        ]);
    }

    private function worker(string $handle, string $name): User
    {
        $user = $this->account($handle, $name);

        WorkerProfile::create([
            'user_id' => $user->id,
            'location' => 'Urdaneta City',
            'location_id' => $this->locationId,
            'category_id' => $this->categoryId,
            'bio' => 'Scenario account.',
            'setup_completed' => true,
        ]);

        DB::table('worker_skills_new')->insert([
            'user_id' => $user->id,
            'skill_name' => 'General Labour',
            'category_id' => $this->categoryId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $user;
    }

    private function employer(string $handle, string $name): User
    {
        $user = $this->account($handle, $name);

        EmployerProfile::create([
            'user_id' => $user->id,
            'employer_type' => 'individual',
            'location' => 'Urdaneta City',
            'location_id' => $this->locationId,
            'description' => 'Scenario employer.',
            'setup_completed' => true,
        ]);

        return $user;
    }

    /*
        Job coordinates, near the centre of Urdaneta City.

        Set explicitly because the live tracking map needs somewhere to route
        to: without a latitude and longitude the destination is null, no line
        is drawn at all, and the scenario cannot demonstrate the feature it
        exists to demonstrate.
    */
    private const JOB_LAT = 15.9761;
    private const JOB_LNG = 120.5711;

    private function job(User $employer, string $title, string $status = 'open'): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id,
            'category_id' => $this->categoryId,
            'title' => $title,
            'description' => 'Scenario job for feature testing.',
            'budget_min' => 900,
            'budget_max' => 1500,
            'budget_period' => 'daily',
            'location' => 'Urdaneta City',
            'location_id' => $this->locationId,
            'latitude' => self::JOB_LAT,
            'longitude' => self::JOB_LNG,
            'status' => $status,
            'start_date' => now()->addDays(3)->toDateString(),
            'application_count' => 1,
        ]);
    }

    private function apply(
        JobPost $job,
        User $worker,
        string $status = 'pending',
        bool $employerDone = false,
        bool $workerDone = false,
    ): Application {
        $application = Application::create([
            'job_id' => $job->id,
            'worker_id' => $worker->id,
            'status' => $status,
        ]);

        $application->forceFill([
            'started_at' => $status === 'pending' ? null : now()->subDay(),
            'employer_completed_at' => $employerDone ? now()->subHours(2) : null,
            'worker_completed_at' => $workerDone ? now()->subHour() : null,
            'completed_at' => ($employerDone && $workerDone) ? now()->subHour() : null,
        ])->save();

        if ($status !== 'pending') {
            $this->conversation($job, $worker);
        }

        return $application;
    }

    private function conversation(JobPost $job, User $worker): Conversation
    {
        return Conversation::firstOrCreate(
            [
                'job_id' => $job->id,
                'employer_id' => $job->employer_id,
                'worker_id' => $worker->id,
            ],
            ['status' => 'unlocked'],
        );
    }

    private function say(Conversation $c, User $from, string $text, bool $read = false): void
    {
        Message::create([
            'conversation_id' => $c->id,
            'sender_id' => $from->id,
            'message_text' => $text,
            'is_read' => $read,
            'read_at' => $read ? now() : null,
        ]);
    }

    private function review(User $from, User $to, JobPost $job, int $rating, string $comment, string $role): void
    {
        Review::create([
            'reviewer_id' => $from->id,
            'reviewee_id' => $to->id,
            'job_id' => $job->id,
            'reviewee_role' => $role,
            'rating' => $rating,
            'comment' => $comment,
        ]);

        $scope = Review::where('reviewee_id', $to->id)->where('reviewee_role', $role);
        $avg = round((float) $scope->avg('rating'), 2);
        $count = $scope->count();

        if ($role === 'worker') {
            $to->workerProfile?->update(['rating_avg' => $avg, 'rating_count' => $count]);
        } else {
            $to->employerProfile?->update(['rating_avg' => $avg, 'rating_count' => $count]);
        }
    }
}
