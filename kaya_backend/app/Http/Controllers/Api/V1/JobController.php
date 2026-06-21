<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\JobPost;
use Illuminate\Http\Request;

class JobController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function index(Request $request)
    {
        $query = JobPost::with(['employer', 'category', 'skills'])
            ->where('status', 'open');

        if ($search = $request->get('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        if ($categoryId = $request->get('category_id')) {
            $query->where('category_id', $categoryId);
        }

        if ($location = $request->get('location')) {
            $query->where('location', 'like', "%{$location}%");
        }

        if ($skillIds = $request->get('skill_ids')) {
            $query->whereHas('skills', fn ($q) => $q->whereIn('skills.id', (array)$skillIds));
        }

        $jobs = $query->latest()->paginate(20);

        return $this->ok($jobs);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        $data = $request->validate([
            'title'              => ['required', 'string', 'max:255'],
            'description'        => ['required', 'string'],
            'category_id'        => ['required', 'exists:categories,id'],
            'required_skill_ids' => ['nullable', 'array'],
            'required_skill_ids.*' => ['exists:skills,id'],
            'budget_min'         => ['nullable', 'numeric', 'min:0'],
            'budget_max'         => ['nullable', 'numeric', 'min:0'],
            'location'           => ['required', 'string', 'max:255'],
            'city'               => ['nullable', 'string', 'max:255'],
        ]);

        $skillIds = $data['required_skill_ids'] ?? [];
        unset($data['required_skill_ids']);

        $job = $user->postedJobs()->create(array_merge($data, ['status' => 'open']));

        if ($skillIds) $job->skills()->sync($skillIds);

        return $this->ok($job->load(['category', 'skills']), 'Job created', 201);
    }

    public function myJobs(Request $request)
    {
        $user = $request->user();
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        $jobs = $user->postedJobs()->with(['category', 'skills'])->latest()->get();
        return $this->ok($jobs);
    }

    public function show(Request $request, JobPost $job)
    {
        $job->load(['employer', 'category', 'skills']);
        $job->employer_information = [
            'name'                => $job->employer->name,
            'verification_status' => $job->employer->is_verified,
            'profile_photo_path'  => $job->employer->profile_picture,
        ];

        return $this->ok($job);
    }

    public function update(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($job->status !== 'open') return $this->fail('Cannot edit job that is not open', 403);

        $data = $request->validate([
            'title'              => ['required', 'string', 'max:255'],
            'description'        => ['required', 'string'],
            'category_id'        => ['required', 'exists:categories,id'],
            'required_skill_ids' => ['nullable', 'array'],
            'required_skill_ids.*' => ['exists:skills,id'],
            'budget_min'         => ['nullable', 'numeric'],
            'budget_max'         => ['nullable', 'numeric'],
            'location'           => ['required', 'string', 'max:255'],
        ]);

        $skillIds = $data['required_skill_ids'] ?? null;
        unset($data['required_skill_ids']);

        $job->update($data);
        if ($skillIds !== null) $job->skills()->sync($skillIds);

        return $this->ok($job->load(['category', 'skills']), 'Job updated');
    }

    public function changeStatus(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $request->validate(['status' => ['required', 'in:open,in_progress,completed,closed']]);
        $job->update(['status' => $request->status]);

        return $this->ok($job, 'Status updated');
    }

    public function destroy(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $job->delete();
        return $this->ok(null, 'Job deleted');
    }

    public function save(Request $request, JobPost $job)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        if ($user->savedJobs()->where('job_id', $job->id)->exists()) {
            return $this->ok(null, 'Job already saved');
        }

        $user->savedJobs()->attach($job->id);
        return $this->ok(null, 'Job saved successfully', 201);
    }

    public function unsave(Request $request, JobPost $job)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $user->savedJobs()->detach($job->id);
        return $this->ok(null, 'Job unsaved successfully');
    }

    public function savedJobs(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $jobs = $user->savedJobs()->with(['employer', 'category', 'skills'])->latest()->get();
        return $this->ok($jobs);
    }
}
