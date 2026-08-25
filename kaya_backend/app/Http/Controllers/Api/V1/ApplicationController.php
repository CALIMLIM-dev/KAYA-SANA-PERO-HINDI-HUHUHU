<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\ApplicationAccepted;
use App\Events\ApplicationRejected;
use App\Events\ApplicationSubmitted;
use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Services\JobCompletionService;
use App\Services\NotificationService;
use App\Services\ScheduleConflictService;
use Illuminate\Http\Request;

class ApplicationController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function apply(Request $request, JobPost $job)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);
        if ($job->status !== 'open') return $this->fail('Job is not accepting applications', 422);

        // Hybrid accounts hold both profiles, so a user can reach their own posting.
        if ($job->employer_id === $user->id) {
            return $this->fail('You cannot apply to your own job', 422);
        }

        if (Application::where('job_id', $job->id)->where('worker_id', $user->id)->exists()) {
            return $this->fail('You have already applied to this job', 422);
        }

        $application = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $user->id,
            'status'    => 'pending',
        ]);

        $job->increment('application_count');

        ApplicationSubmitted::dispatch($application->load(['job', 'worker']));

        return $this->ok($application->load('job'), 'Application submitted', 201);
    }

    public function myApplications(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $applications = $user->applications()
            ->with(['job.employer:id,name,avatar,is_verified', 'job.category'])
            ->latest()
            ->get();

        /*
            The worker's side of the same fix made to jobApplicants.

            Without a thread id here the worker's only route to an employer was
            the Messages tab — while the employer could reach them in one tap
            from the applicant list. One direction of a two-way conversation
            being harder than the other is not a defensible asymmetry.

            One query for the whole list, keyed by job: a worker has at most one
            conversation per job.
        */
        $conversations = Conversation::where('worker_id', $user->id)
            ->whereIn('job_id', $applications->pluck('job_id')->unique())
            ->pluck('id', 'job_id');

        /*
            Where the mutual review stands, for the whole page in one query.

            The card previously offered "Review employer" on every completed job
            regardless of whether one had already been left, so the second tap
            produced a 422 the user could do nothing about. It also never showed
            that the employer had reviewed them — which is the half that makes
            people finish theirs.

            Fetched here rather than per card: a review-status request per row
            would be a dozen round trips to render one screen, which is the
            mistake that made messages feel slow.
        */
        $reviews = \App\Models\Review::whereIn('job_id', $applications->pluck('job_id')->unique())
            ->where(fn ($q) => $q->where('reviewer_id', $user->id)->orWhere('reviewee_id', $user->id))
            ->get(['job_id', 'reviewer_id', 'reviewee_id']);

        $applications->each(function ($application) use ($conversations, $reviews, $user) {
            $application->conversation_id = $conversations[$application->job_id] ?? null;

            $forJob = $reviews->where('job_id', $application->job_id);

            $application->i_reviewed_them   = $forJob->contains('reviewer_id', $user->id);
            $application->they_reviewed_me  = $forJob->contains('reviewee_id', $user->id);
        });

        return $this->ok($applications);
    }

    public function withdraw(Request $request, Application $application)
    {
        $user = $request->user();

        if ($application->worker_id !== $user->id) return $this->fail('Forbidden', 403);

        if ($application->status !== 'pending') {
            return $this->fail('Can only withdraw pending applications', 422);
        }

        $application->update(['status' => 'withdrawn']);

        // Kept in step with the increment in apply(); without this the counter
        // only ever grows and permanently overstates interest in the job.
        JobPost::where('id', $application->job_id)
            ->where('application_count', '>', 0)
            ->decrement('application_count');

        // The employer's shortlist just changed without them doing anything,
        // and a candidate vanishing with no explanation reads as a bug.
        app(NotificationService::class)->applicationWithdrawn($application);

        return $this->ok($application, 'Application withdrawn');
    }

    public function jobApplicants(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        /*
            The thread for each applicant, looked up once for the whole list.

            Without this the app's "Message" button had nowhere specific to go,
            so it opened the whole inbox and left the employer to find the
            person again by name — a second full round trip and a search, to
            reach a conversation the server could have named outright. That is
            what "messages take forever to load" actually was.

            Keyed by worker_id: one conversation per job per pair is now
            guaranteed by a unique index, so this cannot collapse two threads.
        */
        /*
            Keyed by worker alone now that a pair has one thread rather than one
            per job. Filtering by job_id here would return nothing for an
            applicant this employer has messaged about a different job, and the
            Message button on their card would vanish for exactly the people
            they have the longest history with.
        */
        $conversations = Conversation::where('employer_id', $user->id)
            ->pluck('id', 'worker_id');

        // Both halves of the review pair for this job, in one query — see the
        // matching block in myApplications for why this is not fetched per row.
        $reviews = \App\Models\Review::where('job_id', $job->id)
            ->get(['reviewer_id', 'reviewee_id']);

        $reviewedByMe = $reviews->where('reviewer_id', $user->id)->pluck('reviewee_id');
        $reviewedMe   = $reviews->where('reviewee_id', $user->id)->pluck('reviewer_id');

        /*
            "You hired this worker before."

            Rehire needs no new table: a completed application already records
            that a worker did this employer's job. This is the high-value half —
            an employer choosing between five applicants wants to know which one
            they already trust, and that fact is sitting in the database
            unused.

            Counted per worker across all of this employer's OTHER jobs, in one
            query for the whole list.
        */
        $previousHires = Application::query()
            ->where('applications.status', 'completed')
            ->where('applications.job_id', '!=', $job->id)
            ->whereIn('applications.worker_id', $job->applications()->pluck('worker_id'))
            ->join('jobs_posts', 'jobs_posts.id', '=', 'applications.job_id')
            ->where('jobs_posts.employer_id', $user->id)
            ->selectRaw('applications.worker_id, COUNT(*) as total')
            ->groupBy('applications.worker_id')
            ->pluck('total', 'applications.worker_id');

        $applicants = $job->applications()
            ->with(['worker.workerProfile.skills'])
            ->latest()
            ->get()
            ->map(function ($app) use ($conversations, $reviewedByMe, $reviewedMe, $previousHires) {
                $worker  = $app->worker;
                $profile = $worker->workerProfile;

                /*
                    resolvedAvatarUrl() falls back to the user's avatar through
                    $profile->user. That is the same row as $worker, but it is a
                    different relation path, and the eager load above only
                    reaches workerProfile.skills — so Eloquent fetched the user
                    again, once per applicant.

                    Measured on a job with 120 applicants: 137 queries, 121 of
                    them the identical `select * from users where id = ?`.
                    Handing the relation the model already in hand removes all
                    of them without a second trip to the database.
                */
                $profile?->setRelation('user', $worker);

                return [
                    'application_id'        => $app->id,
                    'application_status'    => $app->status,
                    'applied_at'            => $app->created_at,
                    'conversation_id'       => $conversations[$worker->id] ?? null,
                    'i_reviewed_them'       => $reviewedByMe->contains($worker->id),
                    'they_reviewed_me'      => $reviewedMe->contains($worker->id),
                    // Two-sided completion, so the card can offer "Mark as
                    // complete" and then say who is still to confirm.
                    'employer_completed_at' => $app->employer_completed_at,
                    'worker_completed_at'   => $app->worker_completed_at,
                    // How many of this employer's other jobs this worker has
                    // already finished. 0 for a stranger.
                    'times_hired_before'    => (int) ($previousHires[$worker->id] ?? 0),
                    'worker_id'             => $worker->id,
                    'worker_name'           => $worker->name,
                    // Resolved, not a raw storage path — and consistent with
                    // the directory and profile screens.
                    'worker_photo_url'      => $profile?->resolvedAvatarUrl(),
                    'worker_rating'         => $profile?->rating_avg ?? 0,
                    'worker_rating_count'   => $profile?->rating_count ?? 0,
                    'is_verified'           => $worker->is_verified,
                    'skills'                => $profile?->skills->pluck('skill_name')->values() ?? [],
                ];
            });

        return $this->ok($applicants);
    }

    /**
     * One side confirms the work is done.
     *
     * Called by both parties, and which side the caller is on is derived from
     * the job rather than taken from the request — otherwise a worker could
     * confirm on the employer's behalf and review them unilaterally, which is
     * the exact thing two-sided completion exists to prevent.
     */
    public function complete(Request $request, Application $application)
    {
        $user = $request->user();
        $service = app(JobCompletionService::class);

        $application->loadMissing('job');
        $side = $service->sideFor($application, $user);

        if ($side === null) {
            return $this->fail('You were not part of this job', 403);
        }

        if (! in_array($application->status, ['accepted', 'completed'], true)) {
            return $this->fail('Only an accepted hire can be marked complete', 422);
        }

        $application = $service->confirm($application, $side);

        return $this->ok([
            'application' => $application,
            'completion'  => $service->state($application, $side),
            'job_status'  => $application->job?->fresh()?->status,
        ], $application->status === 'completed'
            ? 'Both sides confirmed — this job is complete'
            : 'Marked complete. Waiting for the other side to confirm.');
    }

    public function accept(Request $request, Application $application)
    {
        $user = $request->user();
        $job  = $application->job;

        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($application->status !== 'pending') return $this->fail('Application status must be pending to accept', 422);

        /*
            Refuse rather than double-book.

            cancelClashing() below clears the worker's other PENDING applications
            for these dates, but it deliberately leaves accepted ones alone -- an
            accepted application is a promise to another employer. Without this
            check nothing else looks at those, so two employers could each accept
            the same worker for the same day and neither would ever be told.

            Refusing is the only honest option. Cancelling the earlier hire to
            make room would give the worker to whoever pressed the button last,
            and silently allowing both would send one employer to an empty site.
        */
        $schedule = app(ScheduleConflictService::class);
        $commitment = $schedule->existingCommitment($application->worker_id, $job, $application->id);

        if ($commitment !== null) {
            return $this->fail($schedule->clashMessage($commitment), 422);
        }

        $application->update(['status' => 'accepted']);

        // Mark job in_progress
        $job->update(['status' => 'in_progress']);

        // Unlock or create conversation
        /*
            One thread per pair, reused on every rehire.

            Keyed on the two people rather than the job, so hiring someone a
            second time continues the conversation you already have with them
            instead of opening an empty one beside it. job_id follows the newest
            hire so the chat's job card still says what the work is.
        */
        $conversation = Conversation::firstOrCreate(
            [
                'pair_low' => min($user->id, $application->worker_id),
                'pair_high' => max($user->id, $application->worker_id),
            ],
            [
                'job_id' => $job->id,
                'employer_id' => $user->id,
                'worker_id' => $application->worker_id,
                'status' => 'unlocked',
            ]
        );

        /*
            Roles follow the newest hire.

            The pair identifies the thread; employer_id/worker_id describe who
            is hiring whom *now*. They have to be rewritten because the two can
            swap — the person who hired you last month may be applying to your
            job today — and the chat's job card, the location-sharing offer and
            the review prompt all read from them.
        */
        $conversation->update([
            'status' => 'unlocked',
            'job_id' => $job->id,
            'employer_id' => $user->id,
            'worker_id' => $application->worker_id,
        ]);

        ApplicationAccepted::dispatch($application->load(['job', 'worker']));

        /*
            Auto-withdraw on hire, narrowed to actual collisions.

            Cancelling every other application would punish the worker for being
            hired — hires fall through, and they would have lost their place in
            every other queue for a job that never happened. Only the ones whose
            dates overlap this job are cancelled; the rest stand.

            Returned rather than done silently, so the employer's screen can say
            what changed instead of three other records quietly moving.
        */
        $cancelled = $schedule->cancelClashing($application);

        return $this->ok([
            'application'     => $application,
            'conversation_id' => $conversation->id,
            'cancelled_applications' => $cancelled->map(fn ($a) => [
                'id'        => $a->id,
                'job_id'    => $a->job_id,
                'job_title' => $a->job?->title,
            ])->values(),
        ], 'Application accepted successfully');
    }

    public function reject(Request $request, Application $application)
    {
        $user = $request->user();
        $job  = $application->job;

        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($application->status !== 'pending') return $this->fail('Application status must be pending to reject', 422);

        $application->update(['status' => 'rejected']);

        ApplicationRejected::dispatch($application->load(['job', 'worker']));

        return $this->ok($application, 'Application rejected successfully');
    }
}
