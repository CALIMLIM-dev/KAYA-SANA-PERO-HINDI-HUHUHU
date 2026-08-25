<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\Review;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReviewController extends Controller
{
    /** A review published more than this long ago can no longer be left. */
    private const REVIEW_WINDOW_DAYS = 60;

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function store(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'reviewee_id' => ['required', 'exists:users,id'],
            'job_id'      => ['required', 'exists:jobs_posts,id'],
            'rating'      => ['required', 'integer', 'min:1', 'max:5'],
            'comment'     => ['nullable', 'string', 'max:1000'],
            /*
                What stood out, as short labels.

                Bounded on purpose. The app offers seven fixed chips, but this
                is an open field on the wire, so without a cap it is a place to
                paste a paragraph and have it render as a chip on someone's
                public profile.
            */
            'tags'        => ['nullable', 'array', 'max:5'],
            'tags.*'      => ['string', 'max:40'],
        ]);

        $revieweeId = (int) $data['reviewee_id'];

        if ($revieweeId === $user->id) {
            return $this->fail('You cannot review yourself', 422);
        }

        $job = JobPost::findOrFail($data['job_id']);

        $role = $this->roleOnJob($job, $revieweeId, $user->id);

        if ($role === null) {
            return $this->fail('You can only review someone you worked with on this job', 403);
        }

        /*
            Gated on THIS hire being finished, not on the job's overall status.

            Both sides now confirm completion separately, and a job with two
            hires only reaches 'completed' once every one of them has. Gating on
            the job would make the first pair wait for a third party they have
            nothing to do with.
        */
        $workerId = $role === 'worker' ? $revieweeId : $user->id;

        $hire = Application::where('job_id', $job->id)
            ->where('worker_id', $workerId)
            ->first();

        if ($hire?->status !== 'completed') {
            return $this->fail(
                'You can review once both sides have marked this job complete',
                422
            );
        }

        // Kept as a friendly message even though a unique index now enforces it
        // underneath — a 500 from a constraint violation is not an answer.
        if (Review::where('reviewer_id', $user->id)
            ->where('reviewee_id', $revieweeId)
            ->where('job_id', $job->id)
            ->exists()) {
            return $this->fail('You have already reviewed this person for this job', 422);
        }

        $review = DB::transaction(function () use ($user, $revieweeId, $job, $data, $role) {
            $review = Review::create([
                'reviewer_id'   => $user->id,
                'reviewee_id'   => $revieweeId,
                'job_id'        => $job->id,
                'reviewee_role' => $role,
                'rating'        => $data['rating'],
                'comment'       => $data['comment'] ?? null,
                // Deduplicated and re-indexed, so the same chip sent twice is
                // stored once and the json is a list rather than an object.
                'tags'          => isset($data['tags'])
                    ? array_values(array_unique($data['tags']))
                    : null,
            ]);

            $this->recomputeRating($revieweeId, $role);

            return $review;
        });

        /*
            Tell the person they were reviewed.

            After the transaction, so nothing is announced that could still roll
            back — and the body carries no rating and no text, because reviews
            stay withheld until both sides have written one. A notification
            quoting the review would walk straight around that rule, which
            exists so neither party can tune their review to the one they have
            already read.
        */
        app(NotificationService::class)->reviewReceived($review);

        return $this->ok([
            'review' => $review->load('reviewer:id,name'),
            // So the app can say "waiting for them" rather than going quiet
            // after a submit. This is the whole point of a mutual system: you
            // are told where the other half is.
            'mutual' => $this->mutualState($job, $user->id, $revieweeId),
        ], 'Review submitted', 201);
    }

    /**
     * Where both halves of a job's review stand, for either party.
     *
     * The app previously had no way to ask this, so a completed job showed the
     * same "Leave a review" button whether you had already left one or not, and
     * never showed that the other person had reviewed you.
     */
    public function status(Request $request, JobPost $job)
    {
        $user = $request->user();

        $counterpartId = $this->counterpartId($job, $user->id);

        if ($counterpartId === null) {
            return $this->fail('You were not part of this job', 403);
        }

        return $this->ok([
            'job_id'         => $job->id,
            'job_status'     => $job->status,
            'can_review'     => $job->status === 'completed' && ! $this->withinWindowExpired($job),
            'counterpart'    => User::select('id', 'name', 'avatar', 'is_verified')->find($counterpartId),
            'counterpart_role' => $this->roleOnJob($job, $counterpartId, $user->id),
            'mutual'         => $this->mutualState($job, $user->id, $counterpartId),
        ]);
    }

    /**
     * The role the reviewee was playing, or null if these two were not the two
     * parties on this job.
     *
     * Both directions are checked explicitly. An earlier version passed if
     * EITHER party had an accepted application, which let any hired worker
     * review a stranger.
     */
    private function roleOnJob(JobPost $job, int $revieweeId, int $reviewerId): ?string
    {
        $isHired = fn (int $workerId) => Application::where('job_id', $job->id)
            ->where('worker_id', $workerId)
            // 'completed' as well as 'accepted' — a finished hire moves to
            // 'completed', and checking only 'accepted' meant that the moment a
            // job was actually done, neither party could review the other. The
            // one state where reviewing is allowed was the one state this
            // rejected.
            ->whereIn('status', ['accepted', 'completed'])
            ->exists();

        if ($job->employer_id === $reviewerId && $isHired($revieweeId)) {
            return 'worker';
        }

        if ($job->employer_id === $revieweeId && $isHired($reviewerId)) {
            return 'employer';
        }

        return null;
    }

    /** The other party on this job, from the point of view of $userId. */
    private function counterpartId(JobPost $job, int $userId): ?int
    {
        if ($job->employer_id === $userId) {
            return Application::where('job_id', $job->id)
                ->whereIn('status', ['accepted', 'completed'])
                ->value('worker_id');
        }

        $hired = Application::where('job_id', $job->id)
            ->where('worker_id', $userId)
            // 'completed' as well as 'accepted' — a finished hire moves to
            // 'completed', and checking only 'accepted' meant that the moment a
            // job was actually done, neither party could review the other. The
            // one state where reviewing is allowed was the one state this
            // rejected.
            ->whereIn('status', ['accepted', 'completed'])
            ->exists();

        return $hired ? $job->employer_id : null;
    }

    private function mutualState(JobPost $job, int $userId, ?int $counterpartId): array
    {
        $given = Review::where('job_id', $job->id)
            ->where('reviewer_id', $userId)
            ->where('reviewee_id', $counterpartId)
            ->first();

        $received = Review::where('job_id', $job->id)
            ->where('reviewer_id', $counterpartId)
            ->where('reviewee_id', $userId)
            ->first();

        return [
            'you_reviewed_them' => $given !== null,
            'they_reviewed_you' => $received !== null,
            'complete'          => $given !== null && $received !== null,
            'your_review'       => $given,
            // Only released once you have written yours. Reading their review
            // first and then writing yours in response is how a rating system
            // turns into a negotiation.
            'their_review'      => $given !== null ? $received : null,
        ];
    }

    /**
     * jobs_posts has no completed_at, so this leans on updated_at — the status
     * change to 'completed' is what last touched the row in practice. Good
     * enough for a 60-day window; if the job is ever edited after completion
     * the window simply restarts, which errs towards letting someone review.
     */
    private function withinWindowExpired(JobPost $job): bool
    {
        return $job->updated_at !== null
            && $job->updated_at->lt(now()->subDays(self::REVIEW_WINDOW_DAYS));
    }

    /**
     * Recompute one side of a person's reputation.
     *
     * Scoped by role, which is what keeps a hybrid account's two reputations
     * apart: reviews earned as an employer must not move their worker rating.
     * Recomputed from the table rather than incremented, so a deleted or
     * moderated review cannot leave the average permanently wrong.
     */
    private function recomputeRating(int $userId, string $role): void
    {
        $scope = Review::where('reviewee_id', $userId)->where('reviewee_role', $role);

        $avg   = round((float) $scope->avg('rating'), 2);
        $count = $scope->count();

        $user = User::find($userId);

        if ($role === 'worker') {
            $user?->workerProfile?->update(['rating_avg' => $avg, 'rating_count' => $count]);

            return;
        }

        $user?->employerProfile?->update(['rating_avg' => $avg, 'rating_count' => $count]);
    }
}
