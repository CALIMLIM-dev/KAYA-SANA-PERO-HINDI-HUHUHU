<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
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

        return $this->ok($application->load('job'), 'Application submitted', 201);
    }

    public function myApplications(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $applications = $user->applications()
            ->with(['job.employer', 'job.category'])
            ->latest()
            ->get();

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

        return $this->ok($application, 'Application withdrawn');
    }

    public function jobApplicants(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $applicants = $job->applications()
            ->with(['worker.workerProfile.skills'])
            ->latest()
            ->get()
            ->map(function ($app) {
                $worker  = $app->worker;
                $profile = $worker->workerProfile;
                return [
                    'application_id'        => $app->id,
                    'application_status'    => $app->status,
                    'applied_at'            => $app->created_at,
                    'worker_id'             => $worker->id,
                    'worker_name'           => $worker->name,
                    'worker_photo_url'      => $profile?->profile_photo_path,
                    'worker_rating'         => $profile?->rating_avg ?? 0,
                    'worker_rating_count'   => $profile?->rating_count ?? 0,
                    'is_verified'           => $worker->is_verified,
                    'skills'                => $profile?->skills->pluck('skill_name')->values() ?? [],
                ];
            });

        return $this->ok($applicants);
    }

    public function accept(Request $request, Application $application)
    {
        $user = $request->user();
        $job  = $application->job;

        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($application->status !== 'pending') return $this->fail('Application status must be pending to accept', 422);

        $application->update(['status' => 'accepted']);

        // Mark job in_progress
        $job->update(['status' => 'in_progress']);

        // Unlock or create conversation
        $conversation = Conversation::firstOrCreate(
            ['job_id' => $job->id, 'employer_id' => $user->id, 'worker_id' => $application->worker_id],
            ['status' => 'unlocked']
        );

        if ($conversation->status === 'locked') {
            $conversation->update(['status' => 'unlocked']);
        }

        return $this->ok([
            'application'     => $application,
            'conversation_id' => $conversation->id,
        ], 'Application accepted successfully');
    }

    public function reject(Request $request, Application $application)
    {
        $user = $request->user();
        $job  = $application->job;

        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($application->status !== 'pending') return $this->fail('Application status must be pending to reject', 422);

        $application->update(['status' => 'rejected']);

        return $this->ok($application, 'Application rejected successfully');
    }
}
