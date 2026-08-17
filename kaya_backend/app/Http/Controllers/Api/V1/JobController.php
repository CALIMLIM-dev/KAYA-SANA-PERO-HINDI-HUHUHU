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

        // Attach a match % for the signed-in worker so the job cards can rank
        // and badge them. Same scoring the employer sees on /jobs/{job}/matches.
        $profile = $request->user()?->workerProfile;
        if ($profile) {
            $profile->load('skills');

            $jobs->getCollection()->transform(function (JobPost $job) use ($profile) {
                $match = \App\Services\JobMatchService::score($job, $profile);
                $job->match_score = $match['score'];
                $job->matched_skills = $match['matched_skills'];
                $job->match_reasons = $match['reasons'];
                return $job;
            });
        }

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
            // gte:budget_min rejects an inverted range, which would otherwise be
            // stored happily and then break every salary filter.
            'budget_max'         => ['nullable', 'numeric', 'min:0', 'gte:budget_min'],
            'budget_period'      => ['required', 'in:daily,hourly,project'],
            'location'           => ['required', 'string', 'max:255'],
            'city'               => ['nullable', 'string', 'max:255'],
            'location_id'        => ['nullable', 'exists:locations,id'],
            'latitude'           => ['nullable', 'numeric', 'between:-90,90'],
            'longitude'          => ['nullable', 'numeric', 'between:-180,180'],
            'is_urgent'          => ['nullable', 'boolean'],
            'is_negotiable'      => ['nullable', 'boolean'],
            // At least one job photo, up to 4 — matches the picker's own cap.
            'photos'             => ['required', 'array', 'min:1', 'max:4'],
            'photos.*'           => ['image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ], [
            'budget_max.gte' => 'The maximum budget must be greater than or equal to the minimum budget.',
            'photos.required' => 'Please add at least one photo of the job.',
        ]);

        $skillIds = $data['required_skill_ids'] ?? [];
        unset($data['required_skill_ids']);

        $photoPaths = array_map(
            fn ($photo) => $photo->store('job_photos', 'public'),
            $request->file('photos')
        );
        $data['photos'] = $photoPaths;

        $job = $user->postedJobs()->create(array_merge($data, ['status' => 'open']));

        if ($skillIds) $job->skills()->sync($skillIds);

        return $this->ok($job->load(['category', 'skills']), 'Job created', 201);
    }

    /**
     * GET /jobs/{job}/matches
     *
     * Workers suited to this job, ranked. Shown to the employer right after
     * posting so they can invite people instead of waiting for applications.
     *
     * Scored by JobMatchService — the same weighting a worker sees when
     * browsing jobs, so the percentage never disagrees between the two views.
     * A worker in the same category is always included even with no exact skill
     * overlap, because they can still do the work.
     */
    public function matches(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $job->load('skills');

        $candidates = \App\Models\WorkerProfile::query()
            ->with(['user:id,name,avatar,is_verified,city', 'skills', 'category:id,name'])
            // Never suggest the employer their own worker profile.
            ->where('user_id', '!=', $user->id)
            ->get()
            // Only workers who finished setup are contactable.
            ->filter(fn ($p) => $p->isSetupCompleted());

        $scored = $candidates->map(function ($profile) use ($job) {
            $match = \App\Services\JobMatchService::score($job, $profile);

            return [
                'user_id'        => $profile->user_id,
                'name'           => $profile->user?->name,
                'avatar'         => $profile->user?->avatar,
                'is_verified'    => (bool) $profile->user?->is_verified,
                'location'       => $profile->location,
                'category'       => $profile->category?->name,
                'rating_avg'     => $profile->rating_avg,
                'rating_count'   => $profile->rating_count,
                'skills'         => $profile->skills->pluck('skill_name')->values(),
                'matched_skills' => $match['matched_skills'],
                'match_reasons'  => $match['reasons'],
                'match_score'    => $match['score'],
            ];
        })
        // A same-category worker always clears this, even with no exact skill
        // overlap — they can still do the job.
        ->filter(fn ($m) => $m['match_score'] >= \App\Services\JobMatchService::MIN_VISIBLE_SCORE)
        ->sortByDesc('match_score')
        ->take((int) $request->input('limit', 20))
        ->values();

        return $this->ok($scored);
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
            'employer_id'         => $job->employer_id,
            'name'                => $job->employer->name,
            'verification_status' => $job->employer->is_verified,
            'profile_photo_path'  => $job->employer->avatar,
        ];

        $user = $request->user();

        // Everything the details screen needs to render its Apply/Save state
        // without a second round trip: has this worker already applied, have
        // they saved it, and how well does it match their profile.
        if ($user->workerProfile) {
            $profile = $user->workerProfile;
            $profile->load('skills');
            $match = \App\Services\JobMatchService::score($job, $profile);
            $job->match_score = $match['score'];
            $job->matched_skills = $match['matched_skills'];
        }

        $job->has_applied = $job->applications()->where('worker_id', $user->id)->exists();
        $job->application_status = $job->applications()
            ->where('worker_id', $user->id)
            ->latest()
            ->value('status');
        $job->is_saved = $user->savedJobs()->where('job_id', $job->id)->exists();
        $job->is_own_job = $job->employer_id === $user->id;

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
            'budget_min'         => ['nullable', 'numeric', 'min:0'],
            // gte:budget_min rejects an inverted range, which would otherwise be
            // stored happily and then break every salary filter.
            'budget_max'         => ['nullable', 'numeric', 'min:0', 'gte:budget_min'],
            'budget_period'      => ['nullable', 'in:daily,hourly,project'],
            'location'           => ['required', 'string', 'max:255'],
            'city'               => ['nullable', 'string', 'max:255'],
            'location_id'        => ['nullable', 'exists:locations,id'],
            'latitude'           => ['nullable', 'numeric', 'between:-90,90'],
            'longitude'          => ['nullable', 'numeric', 'between:-180,180'],
            'is_urgent'          => ['nullable', 'boolean'],
            'is_negotiable'      => ['nullable', 'boolean'],
            // Optional here — editing a job doesn't force re-uploading photos.
            'photos'             => ['nullable', 'array', 'max:4'],
            'photos.*'           => ['image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ], [
            'budget_max.gte' => 'The maximum budget must be greater than or equal to the minimum budget.',
        ]);

        $skillIds = $data['required_skill_ids'] ?? null;
        unset($data['required_skill_ids']);

        if ($request->hasFile('photos')) {
            $data['photos'] = array_map(
                fn ($photo) => $photo->store('job_photos', 'public'),
                $request->file('photos')
            );
        } else {
            unset($data['photos']);
        }

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
