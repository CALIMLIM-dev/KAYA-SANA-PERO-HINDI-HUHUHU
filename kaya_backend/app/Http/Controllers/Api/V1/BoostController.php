<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Boost;
use App\Models\JobPost;
use App\Services\BoostService;
use Illuminate\Http\Request;

/*
    Buying placement, for a job post or for the caller's own worker profile.

    One controller for both because it is one purchase. Splitting it would mean
    two prices, two ledger reasons and two chances for them to drift apart,
    which is exactly what happened to the job and worker cards elsewhere in
    this app.
*/
class BoostController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /**
     * Boost a job post the caller owns.
     */
    public function boostJob(Request $request, JobPost $job, BoostService $boosts)
    {
        $user = $request->user();

        if ($job->employer_id !== $user->id) {
            return $this->fail('Forbidden', 403);
        }

        /*
            Only a post somebody can still apply to.

            Paying to put a closed or completed job at the top of the feed buys
            attention for something nobody can act on, and the money would be
            genuinely wasted rather than merely unlucky.
        */
        if (! in_array($job->status, ['open', 'in_progress'], true)) {
            return $this->fail('Only an open job post can be boosted.', 422);
        }

        $boost = $boosts->purchase($user, Boost::TYPE_JOB, $job->id);

        return $this->ok([
            'boost'      => $boost,
            'ends_at'    => $boost->ends_at,
            'is_boosted' => true,
        ], 'This job is now at the top of the feed.');
    }

    /**
     * Boost the caller's own worker profile.
     */
    public function boostProfile(Request $request, BoostService $boosts)
    {
        $user = $request->user();

        if (! $user->isWorker()) {
            return $this->fail('You need a worker profile to boost one.', 422);
        }

        $boost = $boosts->purchase($user, Boost::TYPE_WORKER, $user->id);

        return $this->ok([
            'boost'      => $boost,
            'ends_at'    => $boost->ends_at,
            'is_boosted' => true,
        ], 'Your profile is now at the top of the directory.');
    }
}
