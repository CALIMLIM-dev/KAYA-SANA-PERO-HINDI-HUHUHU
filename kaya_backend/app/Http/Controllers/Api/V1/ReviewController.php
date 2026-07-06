<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\Review;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
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
        ]);

        // Ensure reviewer and reviewee had a relationship for this job
        $hasRelationship = Application::where('job_id', $data['job_id'])
            ->where(function ($q) use ($user, $data) {
                $q->where('worker_id', $user->id)
                  ->orWhere('worker_id', $data['reviewee_id']);
            })
            ->where('status', 'accepted')
            ->exists();

        if (!$hasRelationship) {
            return $this->fail('You can only review someone you worked with', 403);
        }

        // Prevent duplicate reviews
        if (Review::where('reviewer_id', $user->id)
            ->where('reviewee_id', $data['reviewee_id'])
            ->where('job_id', $data['job_id'])
            ->exists()) {
            return $this->fail('You have already reviewed this person for this job', 422);
        }

        $review = Review::create([
            'reviewer_id' => $user->id,
            'reviewee_id' => $data['reviewee_id'],
            'job_id'      => $data['job_id'],
            'rating'      => $data['rating'],
            'comment'     => $data['comment'] ?? null,
        ]);

        // Update reviewee's average rating
        $avg = Review::where('reviewee_id', $data['reviewee_id'])->avg('rating');
        $count = Review::where('reviewee_id', $data['reviewee_id'])->count();

        // Update worker profile rating if reviewee is a worker
        $reviewee = \App\Models\User::find($data['reviewee_id']);
        if ($reviewee?->isWorker()) {
            $reviewee->workerProfile?->update([
                'rating_avg'   => round($avg, 2),
                'rating_count' => $count,
            ]);
        }

        return $this->ok($review->load('reviewer:id,name'), 'Review submitted', 201);
    }
}
