<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\Message;
use App\Models\Review;
use App\Models\Skill;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;

/*
    Plays a whole hire through the real API and checks the RESULT of each step,
    not just its status code.

    kaya:smoke answers "did the endpoint answer". This answers "did the thing
    the endpoint promises actually happen" - accepting an applicant has to open
    a conversation, move the job off `open`, and notify the worker and nobody
    else. A 200 proves none of that.

    Everything is created under a throwaway pair of accounts and removed again
    at the end. Row counts for every table it touches are snapshotted before
    and compared after, so "the test cleaned up after itself" is verified
    rather than assumed. --keep skips teardown when you want to inspect.

        php artisan kaya:simulate
        php artisan kaya:simulate --keep
*/
class SimulateFeatures extends Command
{
    protected $signature = 'kaya:simulate
        {--base=http://127.0.0.1:8000 : server to drive}
        {--keep : leave the simulated data behind for inspection}';

    protected $description = 'Play a full hire through the API and verify what each feature actually did';

    private const TAG = '@kaya-simulation.invalid';

    private string $base;
    private int $passed = 0;
    private array $failures = [];
    private array $counted = [
        'users', 'worker_profiles', 'employer_profiles', 'jobs_posts', 'job_skills',
        'applications', 'conversations', 'messages', 'reviews', 'user_notifications',
        'saved_jobs', 'personal_access_tokens',
    ];
    private array $before = [];

    public function handle(): int
    {
        $this->base = rtrim((string) $this->option('base'), '/');
        $this->before = $this->snapshot();

        $employer = $worker = null;

        try {
            [$employer, $employerToken] = $this->makeEmployer();
            [$worker, $workerToken] = $this->makeWorker();

            $job = $this->featurePostJob($employerToken, $employer);
            $application = $this->featureApply($workerToken, $worker, $job);
            $this->featureApplicantList($employerToken, $job, $worker);
            $conversation = $this->featureAccept($employerToken, $employer, $worker, $job, $application);
            $this->featureMessaging($employerToken, $workerToken, $conversation, $employer, $worker);
            $this->featureSavedJobs($workerToken, $job);
            $this->featureComplete($employerToken, $workerToken, $job, $application, $worker, $employer);
            $this->featureRehire($employerToken, $workerToken, $employer, $worker, $conversation);
            $this->featureNotifications($workerToken, $worker);
            $this->featureSuspension($worker, $workerToken);
        } catch (\Throwable $e) {
            $this->failures[] = 'run aborted: ' . $e->getMessage() . ' @ ' . basename($e->getFile()) . ':' . $e->getLine();
        } finally {
            if ($this->option('keep')) {
                $this->newLine();
                $this->warn('  --keep: simulated data left in place. Accounts end in ' . self::TAG);
            } else {
                $this->teardown();
            }
        }

        $this->newLine();
        foreach ($this->failures as $f) {
            $this->line('  <fg=red>FAIL</>  ' . $f);
        }
        $this->line(sprintf('  %d checks passed, %d failed', $this->passed, count($this->failures)));

        return $this->failures ? self::FAILURE : self::SUCCESS;
    }

    // ------------------------------------------------------------- features

    private function featurePostJob(string $token, User $employer): JobPost
    {
        $this->feature('Posting a job');

        $category = Category::query()->firstOrFail();
        $location = Location::query()->firstOrFail();
        $skill = Skill::query()->where('category_id', $category->id)->first() ?? Skill::query()->first();

        $res = $this->api($token)->attach('photos[]', $this->png(), 'sim.png')->post("{$this->base}/api/v1/jobs", array_filter([
            'title' => 'Simulated job',
            'description' => 'Created by kaya:simulate.',
            'category_id' => $category->id,
            'budget_min' => 500,
            'budget_max' => 900,
            'budget_period' => 'daily',
            'location' => 'Simulation',
            'location_id' => $location->id,
            'start_date' => now()->addDay()->toDateString(),
            'required_skill_ids' => $skill ? [$skill->id] : null,
        ], fn ($v) => $v !== null));

        $this->check('request accepted', $res->status() === 201, 'status ' . $res->status() . ' ' . mb_substr($res->body(), 0, 120));

        $job = JobPost::where('employer_id', $employer->id)->latest('id')->first();
        $this->check('job row exists', $job !== null);
        if (!$job) { throw new \RuntimeException('job was not created'); }

        $this->check("status is 'open', not something the enum lacks", $job->status === 'open', "status={$job->status}");
        $this->check('budget range stored the right way round', (float) $job->budget_min <= (float) $job->budget_max,
            "{$job->budget_min}..{$job->budget_max}");
        if ($skill) {
            $this->check('required skill linked', $job->skills()->count() === 1, 'linked=' . $job->skills()->count());
        }
        $this->check('employer is the poster', (int) $job->employer_id === $employer->id);

        return $job;
    }

    private function featureApply(string $token, User $worker, JobPost $job): Application
    {
        $this->feature('Applying to a job');

        $res = $this->api($token)->post("{$this->base}/api/v1/jobs/{$job->id}/apply", [
            'cover_letter' => 'Simulated application.',
        ]);
        $this->check('application accepted', in_array($res->status(), [200, 201], true), 'status ' . $res->status() . ' ' . mb_substr($res->body(), 0, 120));

        $application = Application::where('job_id', $job->id)->where('worker_id', $worker->id)->first();
        $this->check('application row exists', $application !== null);
        if (!$application) { throw new \RuntimeException('application was not created'); }

        $this->check("starts as 'pending'", $application->status === 'pending', "status={$application->status}");

        $job->refresh();
        $this->check('application_count incremented', (int) $job->application_count === 1, 'count=' . $job->application_count);

        // Applying twice must be refused by the guard, not by a database error.
        $dupe = $this->api($token)->post("{$this->base}/api/v1/jobs/{$job->id}/apply", ['cover_letter' => 'again']);
        $this->check('duplicate application refused with 422, not 500', $dupe->status() === 422, 'status ' . $dupe->status());
        $this->check('duplicate did not create a second row',
            Application::where('job_id', $job->id)->where('worker_id', $worker->id)->count() === 1);

        // The employer should have been told.
        $this->check('employer notified of the applicant',
            UserNotification::where('user_id', $job->employer_id)
                ->where('reference_id', $job->id)->exists());

        return $application;
    }

    /*
        The applicant list showing no skills was a real defect: WorkerProfile
        ::skills() pointed at the dead pre-migration pivot, so every applicant
        looked unskilled to the employer deciding whether to hire them.
    */
    private function featureApplicantList(string $token, JobPost $job, User $worker): void
    {
        $this->feature('Employer views applicants');

        $res = $this->api($token)->get("{$this->base}/api/v1/jobs/{$job->id}/applicants");
        $this->check('applicant list loads', $res->status() === 200, 'status ' . $res->status());

        $body = json_encode($res->json());
        $this->check('the applicant appears in it', str_contains($body, $worker->name), 'worker not found in payload');
        $this->check('their skills are included', str_contains($body, '"skills"'), 'no skills key in payload');
    }

    private function featureAccept(string $token, User $employer, User $worker, JobPost $job, Application $application): Conversation
    {
        $this->feature('Accepting an applicant');

        $notifBefore = UserNotification::where('user_id', $worker->id)->count();

        $res = $this->api($token)->patch("{$this->base}/api/v1/applications/{$application->id}/accept");
        $this->check('accept succeeds', $res->status() === 200, 'status ' . $res->status() . ' ' . mb_substr($res->body(), 0, 140));

        $application->refresh();
        $job->refresh();

        $this->check("application is 'accepted'", $application->status === 'accepted', "status={$application->status}");
        $this->check("job left 'open'", $job->status !== 'open', "status={$job->status}");

        $conversation = Conversation::where('job_id', $job->id)->first();
        $this->check('a conversation was opened', $conversation !== null);
        if (!$conversation) { throw new \RuntimeException('no conversation after accept'); }

        $this->check('conversation joins the right two people',
            (int) $conversation->employer_id === $employer->id && (int) $conversation->worker_id === $worker->id,
            "employer={$conversation->employer_id} worker={$conversation->worker_id}");

        $this->check('worker was notified of the hire',
            UserNotification::where('user_id', $worker->id)->count() > $notifBefore);

        /*
            Address the notification, do not merely count it. An earlier version
            of this check asserted the employer had no "you were hired" row -
            which no code path could ever produce, so it passed even with the
            self-notification guard deliberately disabled. A check that cannot
            fail is worse than none: it reports safety it never tested.
        */
        $hire = UserNotification::where('user_id', $worker->id)
            ->where('type', UserNotification::APPLICATION_ACCEPTED)
            ->latest('id')->first();

        $this->check('the hire notification exists and is addressed to the worker', $hire !== null);
        if ($hire) {
            $this->check('it is filed under the worker audience',
                $hire->audience === UserNotification::AUDIENCE_WORKER, "audience={$hire->audience}");
            $this->check('it points at the application it is about',
                (int) $hire->reference_id === $application->id, "reference_id={$hire->reference_id}");
        }

        return $conversation;
    }

    private function featureMessaging(string $employerToken, string $workerToken, Conversation $conversation, User $employer, User $worker): void
    {
        $this->feature('Messaging');

        $send = $this->api($employerToken)->post("{$this->base}/api/v1/conversations/{$conversation->id}/messages", [
            'message_text' => 'Simulated message from the employer.',
        ]);
        $this->check('employer can send', in_array($send->status(), [200, 201], true), 'status ' . $send->status() . ' ' . mb_substr($send->body(), 0, 120));

        $message = Message::where('conversation_id', $conversation->id)->latest('id')->first();
        $this->check('message stored', $message !== null);
        $this->check('sender recorded correctly', $message && (int) $message->sender_id === $employer->id);

        /*
            A message notifies the OTHER party. Getting this backwards would
            tell people about their own messages and tell nobody about the ones
            they need to see - and every status code would still be 200.
        */
        $toWorker = UserNotification::where('user_id', $worker->id)
            ->where('type', UserNotification::MESSAGE_RECEIVED)
            ->where('reference_id', $conversation->id)->count();
        $toEmployer = UserNotification::where('user_id', $employer->id)
            ->where('type', UserNotification::MESSAGE_RECEIVED)
            ->where('reference_id', $conversation->id)->count();

        $this->check('the recipient was notified', $toWorker === 1, "worker has {$toWorker}");
        $this->check('the sender was not notified of their own message', $toEmployer === 0, "employer has {$toEmployer}");

        $read = $this->api($workerToken)->get("{$this->base}/api/v1/conversations/{$conversation->id}/messages");
        $this->check('worker can read the thread', $read->status() === 200, 'status ' . $read->status());
        $this->check('the message is in the thread', str_contains(json_encode($read->json()), 'Simulated message'));

        // Cursor form is what the app polls; it must return only what is new.
        if ($message) {
            $after = $this->api($workerToken)->get("{$this->base}/api/v1/conversations/{$conversation->id}/messages", [
                'after_id' => $message->id,
            ]);
            // ok() wraps the payload, and the cursor payload is itself {data:[]},
            // so the message array lives at data.data - not data.
            $rows = $after->json('data.data');
            $this->check('polling after the newest id returns nothing',
                $after->status() === 200 && is_array($rows) && count($rows) === 0,
                'returned ' . (is_array($rows) ? count($rows) : gettype($rows)) . ' rows');
        }

        $reply = $this->api($workerToken)->post("{$this->base}/api/v1/conversations/{$conversation->id}/messages", [
            'message_text' => 'Simulated reply from the worker.',
        ]);
        $this->check('worker can reply', in_array($reply->status(), [200, 201], true), 'status ' . $reply->status());

        // Someone outside the conversation must not get in.
        $outsider = User::whereNotIn('id', [$employer->id, $worker->id])->whereHas('employerProfile')->first();
        if ($outsider) {
            $token = $outsider->createToken('kaya-sim-outsider')->plainTextToken;
            $peek = $this->api($token)->get("{$this->base}/api/v1/conversations/{$conversation->id}/messages");
            $this->check('a stranger is refused the thread', in_array($peek->status(), [403, 404], true), 'status ' . $peek->status());
            $outsider->tokens()->where('name', 'kaya-sim-outsider')->delete();
        }
    }

    private function featureSavedJobs(string $token, JobPost $job): void
    {
        $this->feature('Saving a job');

        $save = $this->api($token)->post("{$this->base}/api/v1/jobs/{$job->id}/save");
        $this->check('save accepted', in_array($save->status(), [200, 201], true), 'status ' . $save->status());

        $list = $this->api($token)->get("{$this->base}/api/v1/saved-jobs");
        $this->check('it appears in saved jobs', str_contains(json_encode($list->json()), 'Simulated job'));

        $unsave = $this->api($token)->delete("{$this->base}/api/v1/jobs/{$job->id}/save");
        $this->check('unsave accepted', in_array($unsave->status(), [200, 204], true), 'status ' . $unsave->status());

        $after = $this->api($token)->get("{$this->base}/api/v1/saved-jobs");
        $this->check('it is gone again', !str_contains(json_encode($after->json()), 'Simulated job'));
    }

    /*
        Reviews are supposed to be gated on a finished job. If a review can be
        left before completion, the rating system can be gamed.
    */
    private function featureComplete(string $employerToken, string $workerToken, JobPost $job, Application $application, User $worker, User $employer): void
    {
        $this->feature('Completing the job and reviewing');

        $early = $this->api($workerToken)->post("{$this->base}/api/v1/reviews", [
            'reviewee_id' => $employer->id,
            'job_id' => $job->id,
            'rating' => 5,
            'comment' => 'Too early.',
        ]);
        $this->check('review before completion is refused', $early->status() >= 400, 'status ' . $early->status());

        /*
            Completion is two-sided by design: one party confirming is a claim,
            both confirming is a fact. So the job must NOT be finished after the
            first confirmation, and must be after the second.
        */
        $first = $this->api($employerToken)->patch("{$this->base}/api/v1/applications/{$application->id}/complete");
        $this->check('employer can confirm completion', in_array($first->status(), [200, 201], true),
            'status ' . $first->status() . ' ' . mb_substr($first->body(), 0, 140));

        $application->refresh();
        $this->check('one side alone does not finish the job', $application->status !== 'completed',
            "status={$application->status}");

        $second = $this->api($workerToken)->patch("{$this->base}/api/v1/applications/{$application->id}/complete");
        $this->check('worker can confirm completion', in_array($second->status(), [200, 201], true),
            'status ' . $second->status() . ' ' . mb_substr($second->body(), 0, 140));

        $application->refresh();
        $job->refresh();
        $this->check("application is 'completed'", $application->status === 'completed', "status={$application->status}");
        $this->check("job is 'completed'", $job->status === 'completed', "status={$job->status}");

        $review = $this->api($workerToken)->post("{$this->base}/api/v1/reviews", [
            'reviewee_id' => $employer->id,
            'job_id' => $job->id,
            'rating' => 5,
            'comment' => 'Simulated review.',
        ]);
        $this->check('review after completion is allowed', in_array($review->status(), [200, 201], true), 'status ' . $review->status() . ' ' . mb_substr($review->body(), 0, 140));
        $this->check('review row exists',
            Review::where('job_id', $job->id)->where('reviewer_id', $worker->id)->exists());

        $dupe = $this->api($workerToken)->post("{$this->base}/api/v1/reviews", [
            'reviewee_id' => $employer->id, 'job_id' => $job->id, 'rating' => 1,
        ]);
        $this->check('a second review of the same job is refused', $dupe->status() >= 400, 'status ' . $dupe->status());
    }

    /*
        Hiring the same person again must continue the conversation you already
        have with them, not open a second one beside it. Before this was keyed
        on the pair, every rehire split the history — the messages agreeing how
        the last job went sat in a thread nobody opens again.
    */
    private function featureRehire(
        string $employerToken,
        string $workerToken,
        User $employer,
        User $worker,
        Conversation $firstConversation,
    ): void {
        $this->feature('Rehiring the same worker');

        $category = Category::query()->firstOrFail();
        $location = Location::query()->firstOrFail();

        $before = JobPost::max('id') ?? 0;

        $posted = $this->api($employerToken)->attach('photos[]', $this->png(), 'sim.png')
            ->post("{$this->base}/api/v1/jobs", [
                'title' => 'Simulated second job',
                'description' => 'Rehiring the same worker.',
                'category_id' => $category->id,
                'budget_min' => 700,
                'budget_max' => 1100,
                'budget_period' => 'daily',
                'location' => 'Simulation',
                'location_id' => $location->id,
                'start_date' => now()->addDays(2)->toDateString(),
            ]);
        $this->check('second job posted', $posted->status() === 201, 'status ' . $posted->status());

        $second = JobPost::where('id', '>', $before)->where('employer_id', $employer->id)->latest('id')->first();
        if (!$second) { $this->check('second job exists', false); return; }

        $applied = $this->api($workerToken)->post("{$this->base}/api/v1/jobs/{$second->id}/apply", [
            'cover_letter' => 'Again please.',
        ]);
        $this->check('same worker applied again', in_array($applied->status(), [200, 201], true),
            'status ' . $applied->status());

        $application = Application::where('job_id', $second->id)->where('worker_id', $worker->id)->first();
        if (!$application) { $this->check('second application exists', false); return; }

        $accepted = $this->api($employerToken)
            ->patch("{$this->base}/api/v1/applications/{$application->id}/accept");
        $this->check('rehire accepted', $accepted->status() === 200, 'status ' . $accepted->status());

        $threads = Conversation::where('employer_id', $employer->id)
            ->where('worker_id', $worker->id)->get();

        $this->check('still exactly one thread with this person', $threads->count() === 1,
            'found ' . $threads->count());

        $this->check('it is the same thread as the first hire',
            $threads->first()?->id === $firstConversation->id,
            'was ' . $firstConversation->id . ', now ' . $threads->first()?->id);

        $this->check('the thread now points at the newer job',
            (int) $threads->first()?->job_id === $second->id,
            'job_id=' . $threads->first()?->job_id . ' expected ' . $second->id);

        $this->check('earlier messages are still in it',
            Message::where('conversation_id', $firstConversation->id)->count() > 0);

        // Chatting after a job is finished must keep working - that was the
        // other half of the complaint.
        $stillOpen = $this->api($workerToken)->post(
            "{$this->base}/api/v1/conversations/{$firstConversation->id}/messages",
            ['message_text' => 'Simulated message after completion.'],
        );
        $this->check('a completed job does not close the thread',
            in_array($stillOpen->status(), [200, 201], true), 'status ' . $stillOpen->status());

        /*
            And the other direction.

            Both accounts hold a worker and an employer profile, so the worker
            can turn round and hire the employer. That is still the same two
            people, so it must still be the same single thread — this is the
            case an (employer_id, worker_id) key got wrong.
        */
        // The worker needs an employer side to post at all — isEmployer() is
        // profile existence, so without this the post is a correct 403 and the
        // test would be measuring its own setup.
        EmployerProfile::firstOrCreate(
            ['user_id' => $worker->id],
            ['location_id' => Location::query()->value('id')],
        );

        $reverseJob = $this->api($workerToken)->attach('photos[]', $this->png(), 'sim.png')
            ->post("{$this->base}/api/v1/jobs", [
                'title' => 'Simulated reverse job',
                'description' => 'The worker now hires the employer.',
                'category_id' => $category->id,
                'budget_min' => 400,
                'budget_max' => 800,
                'budget_period' => 'daily',
                'location' => 'Simulation',
                'location_id' => $location->id,
                'start_date' => now()->addDays(3)->toDateString(),
            ]);
        $this->check('the worker can post a job too (hybrid)',
            $reverseJob->status() === 201, 'status ' . $reverseJob->status());

        $posted = JobPost::where('employer_id', $worker->id)->latest('id')->first();
        if (!$posted) { return; }

        // And the employer needs a worker side, for the same reason.
        WorkerProfile::firstOrCreate(
            ['user_id' => $employer->id],
            [
                'category_id' => Category::query()->value('id'),
                'location_id' => Location::query()->value('id'),
            ],
        );

        $applyBack = $this->api($employerToken)
            ->post("{$this->base}/api/v1/jobs/{$posted->id}/apply", ['cover_letter' => 'Turnabout.']);
        $this->check('the original employer can apply to it',
            in_array($applyBack->status(), [200, 201], true), 'status ' . $applyBack->status());

        $reverseApplication = Application::where('job_id', $posted->id)
            ->where('worker_id', $employer->id)->first();
        if (!$reverseApplication) { return; }

        $reverseAccept = $this->api($workerToken)
            ->patch("{$this->base}/api/v1/applications/{$reverseApplication->id}/accept");
        $this->check('the reverse hire is accepted',
            $reverseAccept->status() === 200, 'status ' . $reverseAccept->status());

        $allThreads = Conversation::where(function ($q) use ($employer, $worker) {
            $q->where('employer_id', $employer->id)->where('worker_id', $worker->id);
        })->orWhere(function ($q) use ($employer, $worker) {
            $q->where('employer_id', $worker->id)->where('worker_id', $employer->id);
        })->get();

        $this->check('hiring each other STILL leaves one thread',
            $allThreads->count() === 1, 'found ' . $allThreads->count());

        $this->check('and it is the very same thread',
            $allThreads->first()?->id === $firstConversation->id,
            'was ' . $firstConversation->id . ', now ' . $allThreads->first()?->id);

        $this->check('with the whole history intact',
            Message::where('conversation_id', $firstConversation->id)->count() >= 3);
    }

    private function featureNotifications(string $token, User $worker): void
    {
        $this->feature('Notifications');

        $list = $this->api($token)->get("{$this->base}/api/v1/notifications");
        $this->check('list loads', $list->status() === 200, 'status ' . $list->status());

        $unread = $this->api($token)->get("{$this->base}/api/v1/notifications/unread-count");
        $this->check('unread count loads', $unread->status() === 200, 'status ' . $unread->status());

        $dbUnread = UserNotification::where('user_id', $worker->id)->whereNull('read_at')->count();
        $this->check('unread count is greater than zero after being hired', $dbUnread > 0, "unread={$dbUnread}");

        $this->api($token)->post("{$this->base}/api/v1/notifications/read-all");
        $stillUnread = UserNotification::where('user_id', $worker->id)->whereNull('read_at')->count();
        $this->check('read-all clears them', $stillUnread === 0, "unread after={$stillUnread}");
    }

    /*
        The 23 Aug incident: suspending an account deletes its tokens, and the
        phone then polled a rejected request every few seconds forever because
        signing out needed the token it had just lost.
    */
    private function featureSuspension(User $worker, string $token): void
    {
        $this->feature('Suspension');

        $admin = User::where('user_type', 'admin')->first();
        if (!$admin) {
            $this->check('an admin account exists to suspend with', false, 'no user_type=admin');
            return;
        }

        app(\App\Services\SuspensionService::class)->suspend(
            $worker, reasonCode: 'spam', duration: '1', note: 'kaya:simulate', admin: $admin
        );

        $worker->refresh();
        $this->check('account marked suspended', (bool) $worker->is_suspended);
        $this->check('their tokens were revoked', $worker->tokens()->count() === 0, 'tokens=' . $worker->tokens()->count());

        $blocked = $this->api($token)->get("{$this->base}/api/v1/notifications");
        $this->check('the old token no longer works', $blocked->status() === 401, 'status ' . $blocked->status());

        $out = $this->api($token)->post("{$this->base}/api/v1/logout");
        $this->check('they can still sign out (no 401 loop)', $out->status() === 200, 'status ' . $out->status());

        app(\App\Services\SuspensionService::class)->reinstate($worker);
        $worker->refresh();
        $this->check('reinstating clears the suspension', !$worker->is_suspended);
    }

    // ------------------------------------------------------------- plumbing

    private function makeEmployer(): array
    {
        $u = $this->makeUser('Simulated Employer');
        EmployerProfile::create([
            'user_id' => $u->id,
            'location_id' => Location::query()->value('id'),
        ]);

        return [$u, $u->createToken('kaya-sim')->plainTextToken];
    }

    private function makeWorker(): array
    {
        $u = $this->makeUser('Simulated Worker');
        WorkerProfile::create([
            'user_id' => $u->id,
            'category_id' => Category::query()->value('id'),
            'location_id' => Location::query()->value('id'),
        ]);

        return [$u, $u->createToken('kaya-sim')->plainTextToken];
    }

    private function makeUser(string $name): User
    {
        $u = new User();
        $u->forceFill([
            'name' => $name,
            'email' => 'sim-' . uniqid() . self::TAG,
            'password' => Hash::make('simulation-only'),
            'user_type' => 'worker',
            'email_verified_at' => now(),
            'terms_accepted' => true,
        ])->save();

        return $u;
    }

    private function api(string $token)
    {
        return Http::acceptJson()->withToken($token)->timeout(20);
    }

    private function feature(string $name): void
    {
        $this->newLine();
        $this->line('  <options=bold>' . $name . '</>');
    }

    private function check(string $label, bool $ok, string $detail = ''): void
    {
        if ($ok) {
            $this->passed++;
            $this->line('    <fg=green>ok</>   ' . $label);
            return;
        }
        $this->failures[] = $label . ($detail ? ' -- ' . $detail : '');
        $this->line('    <fg=red>NO</>   ' . $label . ($detail ? '  <fg=gray>(' . $detail . ')</>' : ''));
    }

    private function snapshot(): array
    {
        $out = [];
        foreach ($this->counted as $t) {
            $out[$t] = DB::table($t)->count();
        }

        return $out;
    }

    /*
        Removes everything the run created, then proves it by comparing row
        counts against the snapshot taken before it started. A test that leaves
        debris behind is worse than no test, because the debris looks like data.
    */
    private function teardown(): void
    {
        $this->feature('Disposing of the simulated data');

        try {
            $ids = User::where('email', 'like', '%' . self::TAG)->pluck('id');
            if ($ids->isEmpty()) {
                $this->check('nothing to remove', true);
                return;
            }

            $jobIds = JobPost::whereIn('employer_id', $ids)->pluck('id');
            $convIds = Conversation::whereIn('job_id', $jobIds)->pluck('id');

            DB::transaction(function () use ($ids, $jobIds, $convIds) {
                Message::whereIn('conversation_id', $convIds)->forceDelete();
                Conversation::whereIn('id', $convIds)->forceDelete();
                Review::whereIn('job_id', $jobIds)->orWhereIn('reviewer_id', $ids)->orWhereIn('reviewee_id', $ids)->forceDelete();
                Application::whereIn('job_id', $jobIds)->orWhereIn('worker_id', $ids)->forceDelete();
                DB::table('saved_jobs')->whereIn('job_id', $jobIds)->orWhereIn('worker_id', $ids)->delete();
                DB::table('job_skills')->whereIn('job_id', $jobIds)->delete();
                JobPost::whereIn('id', $jobIds)->forceDelete();
                UserNotification::whereIn('user_id', $ids)->forceDelete();
                DB::table('personal_access_tokens')->whereIn('tokenable_id', $ids)->delete();
                WorkerProfile::whereIn('user_id', $ids)->forceDelete();
                EmployerProfile::whereIn('user_id', $ids)->forceDelete();
                User::whereIn('id', $ids)->forceDelete();
            });

            $this->check('simulated accounts removed',
                User::where('email', 'like', '%' . self::TAG)->count() === 0);

            $after = $this->snapshot();
            $drift = [];
            foreach ($this->before as $table => $n) {
                if ($after[$table] !== $n) {
                    $drift[] = sprintf('%s %+d', $table, $after[$table] - $n);
                }
            }

            $this->check(
                'every table is back to its starting row count',
                $drift === [],
                $drift ? implode(', ', $drift) : ''
            );
        } catch (\Throwable $e) {
            $this->check('teardown completed', false, $e->getMessage());
        }
    }

    private function png(): string
    {
        return base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    }
}
