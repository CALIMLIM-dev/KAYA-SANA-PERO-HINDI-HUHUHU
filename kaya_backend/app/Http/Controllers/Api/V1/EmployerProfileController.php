<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\EmployerType;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreEmployerProfileRequest;
use App\Http\Resources\EmployerProfileResource;
use App\Http\Resources\EmployerVerificationResource;
use App\Models\EmployerProfile;
use App\Services\EmployerVerificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rules\Enum;

class EmployerProfileController extends Controller
{
    public function __construct(
        private EmployerVerificationService $verificationService
    ) {}

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /**
     * Get employer profile and verification status
     * Returns 200 with {profile: null, verification: null} if profile doesn't exist
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $profile = $user->employerProfile;

        // Get verification status
        $verification = $this->verificationService->getEmployerVerification($user, $profile);

        return $this->ok([
            'profile' => $profile ? new EmployerProfileResource($profile) : null,
            'verification' => new EmployerVerificationResource($verification),
        ]);
    }

    /**
     * Create employer profile (first-time setup)
     */
    public function store(StoreEmployerProfileRequest $request)
    {
        $user = $request->user();

        $validated = $request->validated();

        /*
            Idempotent, because setup is not atomic.

            This used to 422 with "already exists" if a profile was here, which
            turned a normal retry into a dead end. Finish creates this row and
            then does more — a photo, a verification, complete-setup — and any
            of those failing (or the user backing out) left the row behind with
            setup unfinished. Coming back and tapping Finish again hit the
            "already exists" wall, and hard-refreshing showed a half-made
            account that could never be completed.

            An account is the user's own, and creating their profile is
            something only they can do to themselves, so re-running it should
            land on the same profile rather than be refused. updateOrCreate
            makes a second Finish overwrite the half-made row instead of
            colliding with it. setup_completed is intentionally not set here —
            that is completeSetup's job, at the very end.

            user_type is still deliberately untouched: profile existence is
            what makes the user an employer (User::isEmployer()), and flipping
            the column used to revoke the same account's worker side.
        */
        $profile = DB::transaction(function () use ($user, $validated) {
            return EmployerProfile::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'employer_type' => $validated['employer_type'],
                    'company_name' => $validated['company_name'] ?? null,
                    'industry' => $validated['industry'] ?? null,
                    'website' => $validated['website'] ?? null,
                    'description' => $validated['description'] ?? null,
                    'location' => $validated['location'],
                    // Structured location from the PSGC picker — nullable so a
                    // profile created before the picker existed still saves.
                    'location_id' => $validated['location_id'] ?? null,
                    'latitude' => $validated['latitude'] ?? null,
                    'longitude' => $validated['longitude'] ?? null,
                ],
            );
        });

        // Get verification status
        $verification = $this->verificationService->getEmployerVerification($user, $profile);

        return $this->ok([
            'profile' => new EmployerProfileResource($profile),
            'verification' => new EmployerVerificationResource($verification),
        ], 'Employer profile created successfully', 201);
    }

    /**
     * Update employer profile
     */
    public function update(Request $request)
    {
        $user = $request->user();
        $profile = $user->employerProfile;

        if (!$profile) {
            return $this->fail('Employer profile not found. Use POST to create.', 404);
        }

        // Use type-specific validation
        $validated = match ($profile->employer_type) {
            EmployerType::COMPANY => $request->validate([
                'company_name' => ['required', 'string', 'max:255'],
                'industry' => ['required', 'string', 'max:255'],
                'location' => ['required', 'string', 'max:255'],
                'location_id' => ['nullable', 'exists:locations,id'],
                'latitude' => ['nullable', 'numeric', 'between:-90,90'],
                'longitude' => ['nullable', 'numeric', 'between:-180,180'],
                'website' => ['nullable', 'url', 'max:255'],
                'description' => ['nullable', 'string', 'max:2000'],
            ]),
            EmployerType::INDIVIDUAL => $request->validate([
                'location' => ['required', 'string', 'max:255'],
                'location_id' => ['nullable', 'exists:locations,id'],
                'latitude' => ['nullable', 'numeric', 'between:-90,90'],
                'longitude' => ['nullable', 'numeric', 'between:-180,180'],
                'description' => ['nullable', 'string', 'max:2000'],
            ]),
            // Profiles created before employer_type existed have a null type.
            // Fall back to the least-restrictive rules instead of throwing a 500.
            default => $request->validate([
                'employer_type' => ['required', new Enum(EmployerType::class)],
                'company_name' => ['nullable', 'string', 'max:255'],
                'industry' => ['nullable', 'string', 'max:255'],
                'location' => ['required', 'string', 'max:255'],
                'website' => ['nullable', 'url', 'max:255'],
                'description' => ['nullable', 'string', 'max:2000'],
            ]),
        };

        // Update profile
        $profile->update($validated);

        // Get verification status
        $verification = $this->verificationService->getEmployerVerification($user, $profile);

        return $this->ok([
            'profile' => new EmployerProfileResource($profile->fresh()),
            'verification' => new EmployerVerificationResource($verification),
        ], 'Profile updated successfully');
    }

    /**
     * Mark onboarding as complete.
     */
    public function completeSetup(Request $request)
    {
        $user = $request->user();
        $profile = $user->employerProfile;

        if (!$profile) {
            return $this->fail('Employer profile not found', 404);
        }

        $profile->setup_completed = true;
        $profile->save();

        return $this->ok(['setup_completed' => true], 'Profile setup completed successfully');
    }

    public function deleteProfile(Request $request)
    {
        $user = $request->user();
        $profile = $user->employerProfile;

        // Silent success if no profile exists
        if ($profile) {
            $profile->delete(); // CASCADE handles related data
        }

        return $this->ok(null, 'Profile deleted successfully');
    }

    /**
     * Upload employer image (company logo or individual photo)
     */
    public function uploadImage(Request $request)
    {
        $user = $request->user();
        $profile = $user->employerProfile;

        if (!$profile) {
            return $this->fail('Employer profile not found. Create profile first.', 404);
        }

        $request->validate([
            'image' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);

        // Delete old image if exists
        if ($profile->image_path) {
            Storage::disk(config('filesystems.media'))->delete($profile->image_path);
        }

        // Store new image
        $path = $request->file('image')->store('employer_images', config('filesystems.media'));

        // Update both image_path (new) and logo_path (legacy) during transition
        $profile->update([
            'image_path' => $path,
            'logo_path' => $path, // Keep in sync during migration
        ]);

        // Refresh profile to get updated data
        $profile = $profile->fresh();

        // Get verification status
        $verification = $this->verificationService->getEmployerVerification($user, $profile);

        // Return consistent response shape
        return $this->ok([
            'profile' => new EmployerProfileResource($profile),
            'verification' => new EmployerVerificationResource($verification),
        ], 'Image uploaded successfully');
    }

    /**
     * GET /employers/{user}
     *
     * Public employer view — shown to a worker who taps "Posted by" on a job.
     * Company/individual info, rating, their open job postings, and reviews
     * received from workers. Only a completed profile has anything to show.
     */
    public function show(Request $request, \App\Models\User $user)
    {
        $profile = $user->employerProfile;

        if (!$profile || !$profile->isSetupCompleted()) {
            return $this->fail('Employer profile not found', 404);
        }

        // Counted as a view of their employer side specifically — a hybrid
        // account's worker view count must not be inflated by people reading
        // their company page.
        app(\App\Services\ProfileViewRecorder::class)->record(
            viewer: $request->user(),
            viewed: $user,
            viewedAs: \App\Models\ProfileView::AS_EMPLOYER,
            source: $request->query('source'),
        );

        $jobs = \App\Models\JobPost::where('employer_id', $user->id)
            ->where('status', 'open')
            ->latest()
            ->limit(20)
            ->get();

        /*
            Their employer reviews only.

            This used to read every review the person had ever received. For a
            hybrid account — worker and employer on the same login, which two of
            the demo accounts are — their company page showed reviews written
            about them as somebody's hired hand, and averaged the two together.
        */
        $reviews = \App\Models\Review::where('reviewee_id', $user->id)
            ->where('reviewee_role', 'employer')
            ->with('reviewer:id,name')
            ->latest()
            ->limit(20)
            ->get();

        return $this->ok([
            'user_id'        => $user->id,
            'name'           => $user->name,
            'avatar'         => $user->avatar,
            'is_verified'    => (bool) $user->is_verified,
            'employer_type'  => $profile->employer_type?->value,
            'company_name'   => $profile->company_name,
            'industry'       => $profile->industry,
            'website'        => $profile->website,
            'description'    => $profile->description,
            'location'       => $profile->location,
            'image_url'      => $profile->image_path ? Storage::disk(config('filesystems.media'))->url($profile->image_path) : null,
            // From the stored aggregate, not from the 20 reviews above — that
            // list is capped for display, so averaging it quietly reported the
            // mean of someone's most recent 20 as their overall rating.
            'rating_avg'     => $profile->rating_count > 0 ? (float) $profile->rating_avg : null,
            'rating_count'   => (int) $profile->rating_count,
            /*
                Counted, not measured off the list.

                The app printed the length of the array below under the label
                "Open Jobs", and the query behind it stops at 20 - so an
                employer with 25 open jobs advertised 20 of them. The same
                mistake the rating average above was already fixed for: a list
                capped for display is not a number about the account.
            */
            'open_jobs_count' => \App\Models\JobPost::where('employer_id', $user->id)
                ->where('status', 'open')
                ->count(),
            /*
                The same completion record the worker profile now carries.

                A worker deciding whether to take a job is asking exactly
                what an employer asks when picking an applicant, and only
                one of them had anything to look at. An employer who keeps
                not confirming completion is a real risk to a worker, and
                until now nothing on the profile could show it.
            */
            ...app(\App\Services\WorkRecord::class)->forEmployer($user),

            'jobs'           => $jobs->map(fn ($j) => [
                'id'         => $j->id,
                'title'      => $j->title,
                'location'   => $j->city ?? $j->location,
                'budget_min' => $j->budget_min,
                'budget_max' => $j->budget_max,
                'posted_at'  => $j->created_at?->diffForHumans(),
            ])->values(),
            'reviews'        => $reviews->map(fn ($r) => [
                'reviewer' => $r->reviewer?->name,
                'rating'   => $r->rating,
                'date'     => $r->created_at?->diffForHumans(),
                'comment'  => $r->comment,
                'tags'     => $r->tags ?? [],
            ])->values(),
        ]);
    }
}
