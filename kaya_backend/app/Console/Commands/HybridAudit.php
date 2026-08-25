<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\Skill;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;

/*
    Attacks the hybrid model instead of demonstrating it.

    One account holding both a worker and an employer profile is the single
    riskiest idea in this product, because every rule written as "the employer"
    or "the worker" quietly assumed those were two different people. Where that
    assumption survives, a hybrid account can act on itself: apply to its own
    job, review itself into a five-star rating, sit in its own applicant list.

    So this does not play a happy path. It creates one hybrid account and tries
    every self-dealing and role-confusion case that a careful reader would ask
    about, and reports what the system actually did. A PASS here means the
    attempt was refused; a FAIL means it worked and should not have.

        php artisan kaya:hybrid-audit
*/
class HybridAudit extends Command
{
    protected $signature = 'kaya:hybrid-audit {--base=http://127.0.0.1:8000}';

    protected $description = 'Try every way a hybrid account could act on itself, and report what happened';

    private const TAG = '@kaya-hybrid-audit.invalid';

    private string $base;
    private int $passed = 0;
    private array $failures = [];
    private array $notes = [];

    public function handle(): int
    {
        $this->base = rtrim((string) $this->option('base'), '/');

        try {
            [$hybrid, $token] = $this->makeHybrid();
            [$other, $otherToken] = $this->makeHybrid('Other Hybrid');

            $this->section('Identity');
            $this->roleResolution($hybrid, $token);

            $job = $this->postJob($token, $hybrid);

            $this->section('Acting on your own job');
            $this->cannotApplyToOwnJob($token, $job, $hybrid);
            $this->cannotInviteSelf($token, $job, $hybrid);
            $this->notNotifiedOfOwnJob($job, $hybrid);
            $this->notInOwnMatches($token, $job, $hybrid);

            $this->section('Appearing to yourself');
            $this->notInOwnWorkerBrowse($token, $hybrid);
            $this->ownJobInOwnFeed($token, $job);

            $this->section('Rating and reporting yourself');
            $this->cannotReviewSelf($token, $job, $hybrid);
            $this->cannotReportSelf($token, $hybrid);

            $this->section('Both roles at once, with a second person');
            $this->bothDirectionsOneThread($token, $otherToken, $hybrid, $other);

            $this->section('Scheduling');
            $this->schedulingClashes($token, $otherToken, $hybrid, $other);

            $this->section('Two reputations, one account');
            $this->reputationsStaySeparate($token, $otherToken, $hybrid, $other);

            $this->section('Not missing things for being in the wrong mode');
            $this->messageNotificationsReachEitherMode($token, $otherToken, $hybrid, $other);
        } catch (\Throwable $e) {
            $this->failures[] = 'aborted: ' . $e->getMessage() . ' @ ' . basename($e->getFile()) . ':' . $e->getLine();
        } finally {
            $this->teardown();
        }

        $this->newLine();
        foreach ($this->notes as $n) {
            $this->line('  <fg=yellow>NOTE</>  ' . $n);
        }
        foreach ($this->failures as $f) {
            $this->line('  <fg=red>HOLE</>  ' . $f);
        }
        $this->line(sprintf('  %d refusals confirmed, %d holes', $this->passed, count($this->failures)));

        return $this->failures ? self::FAILURE : self::SUCCESS;
    }

    // ---------------------------------------------------------------- checks

    private function roleResolution(User $hybrid, string $token): void
    {
        $hybrid->refresh();
        $this->ok('holds a worker profile and an employer profile',
            $hybrid->workerProfile()->exists() && $hybrid->employerProfile()->exists());

        $this->ok('isWorker() and isEmployer() are BOTH true',
            $hybrid->isWorker() && $hybrid->isEmployer());

        $this->ok('user_type is not what decides it',
            $hybrid->user_type !== 'employer',
            'user_type=' . $hybrid->user_type);

        $me = $this->api($token)->get("{$this->base}/api/v1/me");
        $body = json_encode($me->json());
        $this->ok('/me reports both sides so the app can offer the toggle',
            str_contains($body, 'worker_setup_completed') && str_contains($body, 'employer_setup_completed'));
    }

    private function cannotApplyToOwnJob(string $token, JobPost $job, User $hybrid): void
    {
        $res = $this->api($token)->post("{$this->base}/api/v1/jobs/{$job->id}/apply", [
            'cover_letter' => 'Hiring myself.',
        ]);

        $this->ok('applying to your own job is refused', $res->status() === 422,
            'status ' . $res->status());
        $this->ok('and no application row was written',
            Application::where('job_id', $job->id)->where('worker_id', $hybrid->id)->doesntExist());
    }

    private function cannotInviteSelf(string $token, JobPost $job, User $hybrid): void
    {
        $res = $this->api($token)->post("{$this->base}/api/v1/jobs/{$job->id}/invite", [
            'worker_id' => $hybrid->id,
        ]);

        $this->ok('inviting yourself is refused', $res->status() === 422, 'status ' . $res->status());
    }

    /*
        The job-match notifier walks every worker whose skills fit. A hybrid
        fits its own job perfectly, so without an explicit exclusion the poster
        is told about work they just created.
    */
    private function notNotifiedOfOwnJob(JobPost $job, User $hybrid): void
    {
        $this->ok('posting a job does not notify you about your own job',
            UserNotification::where('user_id', $hybrid->id)
                ->where('type', 'job.match')
                ->where('reference_id', $job->id)
                ->doesntExist());
    }

    private function notInOwnMatches(string $token, JobPost $job, User $hybrid): void
    {
        $res = $this->api($token)->get("{$this->base}/api/v1/jobs/{$job->id}/matches");

        if ($res->status() !== 200) {
            $this->note('matches endpoint returned ' . $res->status() . ' — could not check');
            return;
        }

        $this->ok('you are not offered as a match for your own job',
            ! $this->containsUser($res->json(), $hybrid->id));
    }

    private function notInOwnWorkerBrowse(string $token, User $hybrid): void
    {
        $res = $this->api($token)->get("{$this->base}/api/v1/workers", ['per_page' => 50]);

        if ($res->status() !== 200) {
            $this->note('worker browse returned ' . $res->status() . ' — could not check');
            return;
        }

        $present = $this->containsUser($res->json(), $hybrid->id);
        if ($present) {
            $this->note('you appear in your own worker browse results — cosmetic, but an employer '
                . 'scrolling for someone to hire should probably not find themselves');
        } else {
            $this->ok('you do not appear in your own worker browse results', true);
        }
    }

    private function ownJobInOwnFeed(string $token, JobPost $job): void
    {
        $res = $this->api($token)->get("{$this->base}/api/v1/jobs", ['per_page' => 100]);

        if ($res->status() !== 200) {
            $this->note('job feed returned ' . $res->status() . ' — could not check');
            return;
        }

        /*
            The feed is "work you could take", and your own job is not that.
            Applying to it is refused, so leaving it listed meant an Apply button
            that could only ever fail -- which is worse than not showing it.
        */
        $this->ok('your own job is not listed as work you could take',
            ! str_contains(json_encode($res->json()), '"id":' . $job->id));
    }

    private function cannotReviewSelf(string $token, JobPost $job, User $hybrid): void
    {
        $res = $this->api($token)->post("{$this->base}/api/v1/reviews", [
            'reviewee_id' => $hybrid->id,
            'job_id' => $job->id,
            'rating' => 5,
            'comment' => 'Excellent work by me.',
        ]);

        $this->ok('reviewing yourself is refused', $res->status() >= 400, 'status ' . $res->status());
        $this->ok('and no review row was written',
            \App\Models\Review::where('reviewer_id', $hybrid->id)
                ->where('reviewee_id', $hybrid->id)->doesntExist());
    }

    private function cannotReportSelf(string $token, User $hybrid): void
    {
        $res = $this->api($token)->post("{$this->base}/api/v1/reports", [
            'reported_id' => $hybrid->id,
            'reason_code' => 'spam',
            'details' => 'Reporting myself.',
        ]);

        $this->ok('reporting yourself is refused', $res->status() >= 400, 'status ' . $res->status());
    }

    /*
        The case that broke the per-job and per-role keys: two hybrids hiring
        each other. Whatever the roles, two people must have one thread.
    */
    private function bothDirectionsOneThread(
        string $tokenA, string $tokenB, User $a, User $b,
    ): void {
        $jobA = $this->postJob($tokenA, $a, 'Hybrid audit — A hires B');
        $this->hire($tokenA, $tokenB, $jobA, $b);

        $jobB = $this->postJob($tokenB, $b, 'Hybrid audit — B hires A');
        $this->hire($tokenB, $tokenA, $jobB, $a);

        $threads = Conversation::where('pair_low', min($a->id, $b->id))
            ->where('pair_high', max($a->id, $b->id))
            ->get();

        $this->ok('two hybrids hiring each other still share ONE thread',
            $threads->count() === 1, 'found ' . $threads->count());

        $this->ok('no conversation can exist between a person and themselves',
            Conversation::whereColumn('pair_low', 'pair_high')->doesntExist());
    }

    /*
        Scheduling is the part a panel is most likely to push on, because it is
        where "one person, two roles" stops being a display concern and starts
        being a promise about someone's time.

        Three questions, answered by doing them rather than by reading the code:
        does being hired clear the applications that collide, does it leave the
        ones that do not, and can the same person be hired twice for one day.
    */
    private function schedulingClashes(
        string $tokenA, string $tokenB, User $a, User $b,
    ): void {
        $tuesday = now()->addDays(7)->toDateString();
        $friday = now()->addDays(10)->toDateString();

        $clashing = $this->postJob($tokenA, $a, 'Audit clash', $tuesday);
        $sameDay = $this->postJob($tokenA, $a, 'Audit same day', $tuesday);
        $otherDay = $this->postJob($tokenA, $a, 'Audit other day', $friday);

        foreach ([$clashing, $sameDay, $otherDay] as $job) {
            $this->api($tokenB)->post("{$this->base}/api/v1/jobs/{$job->id}/apply", [
                'cover_letter' => 'Hybrid audit.',
            ]);
        }

        $hired = Application::where('job_id', $clashing->id)
            ->where('worker_id', $b->id)->first();

        if (! $hired) {
            $this->note('could not seed the scheduling case -- skipped');

            return;
        }

        $res = $this->api($tokenA)
            ->patch("{$this->base}/api/v1/applications/{$hired->id}/accept");

        $this->ok('accepting a worker reports what it cancelled for them',
            is_array($res->json('data.cancelled_applications')));

        $this->ok('a pending application on the SAME date is cancelled',
            Application::where('job_id', $sameDay->id)
                ->where('worker_id', $b->id)->value('status') === 'cancelled');

        $this->ok('a pending application on a DIFFERENT date survives',
            Application::where('job_id', $otherDay->id)
                ->where('worker_id', $b->id)->value('status') === 'pending');

        /*
            The one a panel will actually ask about.

            cancelClashing only sweeps applications still in 'pending'. One that
            is already 'accepted' is a real commitment to another employer, so
            cancelling it silently would be wrong -- but nothing else looks at it
            either, so a second employer can accept the same worker for the same
            day and nobody is told.
        */
        $double = $this->postJob($tokenA, $a, 'Audit double booking', $tuesday);
        $this->api($tokenB)->post("{$this->base}/api/v1/jobs/{$double->id}/apply", [
            'cover_letter' => 'Hybrid audit.',
        ]);

        $second = Application::where('job_id', $double->id)
            ->where('worker_id', $b->id)->first();

        if (! $second) {
            $this->note('could not seed the double-booking case -- skipped');

            return;
        }

        $accept = $this->api($tokenA)
            ->patch("{$this->base}/api/v1/applications/{$second->id}/accept");

        $live = Application::whereIn('job_id', [$clashing->id, $double->id])
            ->where('worker_id', $b->id)
            ->where('status', 'accepted')
            ->count();

        $this->ok('a second employer cannot hire a worker for a date they are booked on',
            $accept->status() === 422, 'status ' . $accept->status());

        $this->ok('and only the first hire stands',
            $live === 1, $live . ' accepted hires on the same date');

        $this->ok('the refusal says when, without naming the other employer',
            str_contains(strtolower((string) $accept->json('message')), 'already hired')
            && ! str_contains((string) $accept->json('message'), $a->name),
            (string) $accept->json('message'));

        /*
            The same collision reached from the other side. Accepting an
            invitation also writes an accepted application, so the guard has to
            sit on both paths or the worker can simply take the invite instead.
        */
        $inviteJob = $this->postJob($tokenA, $a, 'Audit invite clash', $tuesday);
        $this->api($tokenA)->post("{$this->base}/api/v1/jobs/{$inviteJob->id}/invite", [
            'worker_id' => $b->id,
        ]);

        $invitation = \App\Models\Invitation::where('job_id', $inviteJob->id)
            ->where('worker_id', $b->id)->first();

        if ($invitation === null) {
            $this->note('could not seed the invitation clash -- skipped');

            return;
        }

        $res = $this->api($tokenB)
            ->patch("{$this->base}/api/v1/invitations/{$invitation->id}/accept");

        $this->ok('a worker cannot accept an invitation for a date they are booked on',
            $res->status() === 422, 'status ' . $res->status());
    }

    /*
        The question a panel asks the moment they accept that one account can do
        both jobs: this person has four stars -- at what?

        A rating that mixed the two would be worse than useless. It would let a
        good worker inherit trust as an employer they never earned, and it would
        make the number unreadable for the person deciding whether to hire.

        So each side is scored separately, and this proves it by giving one
        account deliberately opposite ratings in its two roles and checking the
        two numbers land in different places and do not move each other.
    */
    private function reputationsStaySeparate(
        string $tokenA, string $tokenB, User $a, User $b,
    ): void {
        // Distinct dates: hiring each other on one day would now be refused by
        // the double-booking guard above, which is correct and not what this
        // section is testing.
        $asWorker = $this->completedJob($tokenB, $tokenA, $b, $a, now()->addDays(20)->toDateString());
        $asEmployer = $this->completedJob($tokenA, $tokenB, $a, $b, now()->addDays(25)->toDateString());

        if ($asWorker === null || $asEmployer === null) {
            $this->note('could not complete a job in both directions -- skipped');

            return;
        }

        // A worked for B and was excellent. A hired B and was a poor employer.
        $this->review($tokenB, $a->id, $asWorker, 5);
        $this->review($tokenB, $a->id, $asEmployer, 1);

        $a->refresh()->load(['workerProfile', 'employerProfile']);

        $workerRating = (float) ($a->workerProfile?->rating_avg ?? 0);
        $employerRating = (float) ($a->employerProfile?->rating_avg ?? 0);

        $this->ok('a review earned as a WORKER lands on the worker rating',
            $workerRating === 5.0, 'worker rating ' . $workerRating);

        $this->ok('a review earned as an EMPLOYER lands on the employer rating',
            $employerRating === 1.0, 'employer rating ' . $employerRating);

        $this->ok('the two ratings do not contaminate each other',
            $workerRating !== $employerRating);

        $this->ok('each side counts only its own reviews',
            (int) ($a->workerProfile?->rating_count ?? 0) === 1
            && (int) ($a->employerProfile?->rating_count ?? 0) === 1);

        $this->ok('every review records which role it was earned in',
            \App\Models\Review::where('reviewee_id', $a->id)
                ->whereNull('reviewee_role')->doesntExist());
    }

    /**
     * Runs a job all the way to completed and returns its id.
     *
     * Completion needs BOTH sides to confirm, so this is the only way to reach
     * a state where reviewing is allowed at all.
     */
    private function completedJob(
        string $employerToken,
        string $workerToken,
        User $employer,
        User $worker,
        string $startDate,
    ): ?int {
        $job = $this->postJob($employerToken, $employer, 'Audit reputation', $startDate);

        $this->api($workerToken)->post("{$this->base}/api/v1/jobs/{$job->id}/apply", [
            'cover_letter' => 'Hybrid audit.',
        ]);

        $application = Application::where('job_id', $job->id)
            ->where('worker_id', $worker->id)->first();

        if ($application === null) {
            return null;
        }

        $this->api($employerToken)
            ->patch("{$this->base}/api/v1/applications/{$application->id}/accept");

        foreach ([$employerToken, $workerToken] as $token) {
            $this->api($token)
                ->patch("{$this->base}/api/v1/applications/{$application->id}/complete");
        }

        return $application->fresh()->status === 'completed' ? $job->id : null;
    }

    private function review(string $token, int $revieweeId, int $jobId, int $rating): void
    {
        $this->api($token)->post("{$this->base}/api/v1/reviews", [
            'reviewee_id' => $revieweeId,
            'job_id' => $jobId,
            'rating' => $rating,
            'comment' => 'Hybrid audit.',
        ]);
    }

    /*
        The inbox is not filtered by mode, so its notifications must not be
        either.

        Every other notification belongs to one role -- an application is
        employer news, an invitation is worker news -- and filtering those by
        mode is right. A message is the exception, because the thread it points
        at is shared. Scope it to the role of the LATEST job and a hybrid
        sitting in the other mode gets no banner and no bell, for a conversation
        they can see in their own inbox. The roles on a thread also swap when
        the two of you hire each other, so which mode hides it changes over
        time.

        Modelled the way the client filters: itemsFor(mode) keeps the rows whose
        audience matches the mode, so a message must survive both passes.
    */
    private function messageNotificationsReachEitherMode(
        string $tokenA, string $tokenB, User $a, User $b,
    ): void {
        // B hires A, so on the newest job A is the worker.
        $job = $this->postJob($tokenB, $b, 'Audit message audience', now()->addDays(40)->toDateString());
        $this->hire($tokenB, $tokenA, $job, $a);

        $conversation = Conversation::where('pair_low', min($a->id, $b->id))
            ->where('pair_high', max($a->id, $b->id))
            ->first();

        if ($conversation === null) {
            $this->note('no conversation to message in -- skipped');

            return;
        }

        $sent = $this->api($tokenB)
            ->post("{$this->base}/api/v1/conversations/{$conversation->id}/messages", [
                'message_text' => 'Hybrid audit message.',
            ]);

        if ($sent->status() >= 400) {
            $this->note('could not send a message (' . $sent->status() . ') -- skipped');

            return;
        }

        $notification = UserNotification::where('user_id', $a->id)
            ->where('type', 'message.received')
            ->where('reference_id', $conversation->id)
            ->latest('id')
            ->first();

        $this->ok('the message produced a notification for the recipient',
            $notification !== null);

        if ($notification === null) {
            return;
        }

        // What the client would show in each mode.
        $seenAsWorker = $this->visibleInMode($notification->audience, 'worker');
        $seenAsEmployer = $this->visibleInMode($notification->audience, 'employer');

        $this->ok('a message notification shows in BOTH modes, like the thread it opens',
            $seenAsWorker && $seenAsEmployer,
            'audience=' . $notification->audience
                . ' visible: worker=' . ($seenAsWorker ? 'yes' : 'no')
                . ' employer=' . ($seenAsEmployer ? 'yes' : 'no'));

        // Role-specific news must still be scoped, or the fix has gone too far.
        $applicationNews = UserNotification::where('user_id', $b->id)
            ->where('type', 'application.received')
            ->latest('id')
            ->first();

        if ($applicationNews !== null) {
            $this->ok('news that belongs to one role is still scoped to it',
                $applicationNews->audience === 'employer',
                'audience=' . $applicationNews->audience);
        }
    }

    /** Mirrors NotificationProvider.itemsFor(mode) in the app. */
    private function visibleInMode(string $audience, string $mode): bool
    {
        return $audience === $mode || $audience === 'both';
    }

    // -------------------------------------------------------------- plumbing

    private function hire(string $employerToken, string $workerToken, JobPost $job, User $worker): void
    {
        $this->api($workerToken)->post("{$this->base}/api/v1/jobs/{$job->id}/apply", [
            'cover_letter' => 'Hybrid audit.',
        ]);

        $application = Application::where('job_id', $job->id)
            ->where('worker_id', $worker->id)->first();

        if ($application) {
            $this->api($employerToken)
                ->patch("{$this->base}/api/v1/applications/{$application->id}/accept");
        }
    }

    private function postJob(
        string $token,
        User $employer,
        string $title = 'Hybrid audit job',
        ?string $startDate = null,
    ): JobPost {
        $category = Category::query()->firstOrFail();
        $location = Location::query()->firstOrFail();
        $skill = Skill::query()->where('category_id', $category->id)->first() ?? Skill::query()->first();

        $this->api($token)->attach('photos[]', $this->png(), 'a.png')
            ->post("{$this->base}/api/v1/jobs", array_filter([
                'title' => $title,
                'description' => 'Created by kaya:hybrid-audit.',
                'category_id' => $category->id,
                'budget_min' => 500,
                'budget_max' => 900,
                'budget_period' => 'daily',
                'location' => 'Audit',
                'location_id' => $location->id,
                'start_date' => $startDate ?? now()->addDay()->toDateString(),
                'required_skill_ids' => $skill ? [$skill->id] : null,
            ], fn ($v) => $v !== null));

        return JobPost::where('employer_id', $employer->id)->latest('id')->firstOrFail();
    }

    /** @return array{0: User, 1: string} */
    private function makeHybrid(string $name = 'Hybrid Account'): array
    {
        $user = new User();
        $user->forceFill([
            'name' => $name,
            'email' => 'hybrid-' . uniqid() . self::TAG,
            'password' => Hash::make('audit-only'),
            'user_type' => 'worker',
            'email_verified_at' => now(),
            'terms_accepted' => true,
        ])->save();

        $categoryId = Category::query()->value('id');
        $locationId = Location::query()->value('id');

        /*
            location and category are both required by the browse query. Without
            them this profile is filtered out before any self-exclusion rule can
            run, and "you do not appear in your own results" would pass for the
            wrong reason.
        */
        WorkerProfile::create([
            'user_id' => $user->id,
            'category_id' => $categoryId,
            'location_id' => $locationId,
            'location' => 'Audit City',
        ]);
        EmployerProfile::create([
            'user_id' => $user->id,
            'location_id' => $locationId,
        ]);

        return [$user, $user->createToken('kaya-hybrid-audit')->plainTextToken];
    }

    private function containsUser(mixed $payload, int $userId): bool
    {
        $json = json_encode($payload);

        return str_contains($json, '"user_id":' . $userId)
            || str_contains($json, '"id":' . $userId . ',"name"');
    }

    private function api(string $token)
    {
        return Http::acceptJson()->withToken($token)->timeout(20);
    }

    private function section(string $name): void
    {
        $this->newLine();
        $this->line('  <options=bold>' . $name . '</>');
    }

    private function ok(string $label, bool $passed, string $detail = ''): void
    {
        if ($passed) {
            $this->passed++;
            $this->line('    <fg=green>ok</>   ' . $label);

            return;
        }
        $this->failures[] = $label . ($detail ? ' -- ' . $detail : '');
        $this->line('    <fg=red>NO</>   ' . $label . ($detail ? '  <fg=gray>(' . $detail . ')</>' : ''));
    }

    private function note(string $text): void
    {
        $this->notes[] = $text;
        $this->line('    <fg=yellow>--</>   ' . $text);
    }

    private function teardown(): void
    {
        $this->section('Cleaning up');

        try {
            $ids = User::where('email', 'like', '%' . self::TAG)->pluck('id');
            if ($ids->isEmpty()) {
                $this->ok('nothing to remove', true);

                return;
            }

            $jobIds = JobPost::whereIn('employer_id', $ids)->pluck('id');
            $convIds = Conversation::whereIn('pair_low', $ids)
                ->orWhereIn('pair_high', $ids)->pluck('id');

            DB::transaction(function () use ($ids, $jobIds, $convIds) {
                \App\Models\Message::whereIn('conversation_id', $convIds)->forceDelete();
                Conversation::whereIn('id', $convIds)->forceDelete();
                \App\Models\Review::whereIn('reviewer_id', $ids)->orWhereIn('reviewee_id', $ids)->forceDelete();
                Application::whereIn('job_id', $jobIds)->orWhereIn('worker_id', $ids)->forceDelete();
                DB::table('invitations')->whereIn('employer_id', $ids)->orWhereIn('worker_id', $ids)->delete();
                DB::table('reports')->whereIn('reporter_id', $ids)->orWhereIn('reported_id', $ids)->delete();
                DB::table('saved_jobs')->whereIn('job_id', $jobIds)->orWhereIn('worker_id', $ids)->delete();
                DB::table('job_skills')->whereIn('job_id', $jobIds)->delete();
                JobPost::whereIn('id', $jobIds)->forceDelete();
                UserNotification::whereIn('user_id', $ids)->forceDelete();
                DB::table('personal_access_tokens')->whereIn('tokenable_id', $ids)->delete();
                WorkerProfile::whereIn('user_id', $ids)->forceDelete();
                EmployerProfile::whereIn('user_id', $ids)->forceDelete();
                User::whereIn('id', $ids)->forceDelete();
            });

            $this->ok('audit accounts and their data removed',
                User::where('email', 'like', '%' . self::TAG)->doesntExist());
        } catch (\Throwable $e) {
            $this->ok('cleanup completed', false, $e->getMessage());
        }
    }

    private function png(): string
    {
        return base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    }
}
