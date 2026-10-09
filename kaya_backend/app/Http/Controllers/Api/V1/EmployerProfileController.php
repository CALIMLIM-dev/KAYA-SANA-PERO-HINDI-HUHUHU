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
        /*
            One person lives in one place. See SharedIdentity: a hybrid
            account used to keep two locations, so moving town on one side
            left the other advertising the old one.
        */
        $verification = $this->verificationService->getEmployerVerification($user, $profile);

        return $this->ok([
            'profile' => $profile ? new EmployerProfileResource($profile) : null,
            'verification' => new EmployerVerificationResource($verification),
        ]);
    }

    /*
        The employer profile of an account that already has a worker one.

        The mirror of WorkerProfileController::storeFromAccount, and the easier
        half of it. The setup flow asks a worker three more pages of questions
        it already has the answers to: the name is locked and prefilled, the
        town comes from the other profile, and the photo and the ID are the
        account's, not the profile's. Walking them changes nothing.

        Unlike the worker direction this needs no question at all. That one had
        to ask for a trade, because browse() filters on the category and there
        is nothing on the account that could supply it. Here the only two
        required fields are the type and the location, and both are already
        determined: an account that looks for work can only be an individual
        employer, and it lives where its worker profile says it lives.
    */
    public function storeFromAccount(Request $request)
    {
        $user = $request->user();

        if ($user->employerProfile !== null) {
            return $this->fail('You already have an employer profile.');
        }

        /*
            There is nothing to inherit without the other profile.

            An account with neither has no town and no confirmed name, so it
            belongs in the full setup flow - and a profile created here would
            have a null location, which is the state that makes a profile
            invisible to proximity search.
        */
        $worker = $user->workerProfile;

        if ($worker === null) {
            return $this->fail(
                'Set up your worker profile first, or use the full employer setup.'
            );
        }

        if (blank($worker->location)) {
            return $this->fail('Add a location to your worker profile first.');
        }

        /*
            Individual, and not offered as a choice.

            The one exception to an account holding both profiles: a registered
            business hiring through KAYA is not also a tradesperson looking for
            work. store() and update() both refuse COMPANY on an account with a
            worker profile, so a company created here would only be refused by
            them a moment later.
        */
        $profile = EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => EmployerType::INDIVIDUAL->value,
            // Inherited whole, coordinates included. A label with no id has no
            // coordinates, and without those every distance on a job card this
            // employer posts is measured from nowhere.
            'location'      => $worker->location,
            'location_id'   => $worker->location_id,
            'latitude'      => $worker->latitude,
            'longitude'     => $worker->longitude,
        ]);

        /*
            And the account's own city follows, as it does on any other save.

            The worker profile is the source here so nothing actually moves,
            but going through the one service stops this path becoming the
            exception that drifts.
        */
        app(\App\Services\SharedIdentity::class)->spreadLocation(
            $user,
            $profile->location,
            $profile->location_id,
            $profile->latitude === null ? null : (float) $profile->latitude,
            $profile->longitude === null ? null : (float) $profile->longitude,
        );

        $verification = $this->verificationService->getEmployerVerification($user, $profile);

        return $this->ok([
            'profile'      => new EmployerProfileResource($profile),
            'verification' => new EmployerVerificationResource($verification),
        ], 'Employer profile created', 201);
    }
    /**
     * Create employer profile (first-time setup)
     */
    public function store(StoreEmployerProfileRequest $request)
    {
        $user = $request->user();

        $validated = $request->validated();

        /*
            A worker account cannot become a company.

            The mirror of the guard in WorkerProfileController. Without
            it the exclusivity rule is one-directional and trivially
            avoidable: make the worker profile first, then declare the
            employer side a company, and the account ends up in exactly
            the state the other guard refuses to create.

            Individual is not blocked. That is the ordinary hybrid case
            the app is built around - a tradesperson who also hires - and
            nothing about it is being changed.
        */
        if ($user->isWorker()
            && ($validated['employer_type'] ?? null) === EmployerType::COMPANY->value) {
            return $this->fail(
                'This account has a worker profile, so the employer side has '
                . 'to stay Individual. Business accounts cannot also look for '
                . 'work.',
                422
            );
        }

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
                    /*
                        The TIN, normalised.

                        Stored here rather than waiting for the document
                        upload, because the admin panel refuses to approve
                        a business without checking this number on ORUS -
                        and that check was being skipped for every company,
                        since there was never a number on file to check.
                    */
                    'tin' => isset($validated['tin'])
                        ? EmployerProfile::normaliseTin($validated['tin'])
                        : null,
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
        /*
            One person lives in one place. See SharedIdentity: a hybrid
            account used to keep two locations, so moving town on one side
            left the other advertising the old one.
        */
        app(\App\Services\SharedIdentity::class)->spreadLocation(
            $user,
            $profile->location,
            $profile->location_id,
            $profile->latitude === null ? null : (float) $profile->latitude,
            $profile->longitude === null ? null : (float) $profile->longitude,
        );

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

        /*
            Digits only, before the rules run.

            Creating a profile goes through StoreEmployerProfileRequest, which
            strips the punctuation in prepareForValidation. This endpoint
            validates inline, so it has to do the same thing - otherwise the
            number typed the way it is printed, 123-456-789-000, passes on the
            way in and is refused on the way to correcting a typo.
        */
        if ($request->filled('tin')) {
            $request->merge([
                'tin' => preg_replace('/\D/', '', (string) $request->input('tin')),
            ]);
        }

        /*
            Partial updates, because that is what this endpoint receives.

            The profile screen edits one row at a time - a description here, a
            location there - so a request carries one field. These rules had
            `required` on location (and on company_name and industry), which
            made every one of those single-field saves fail with "the location
            field is required" about a location the profile already had and the
            user was not touching.

            `sometimes` keeps the rule where it matters - a location that IS
            sent still has to be a real one, and cannot be blanked - while
            letting the other rows save on their own. Creation still requires
            everything: StoreEmployerProfileRequest is unchanged, and that is
            the place a profile has to be complete.
        */
        $validated = match ($profile->employer_type) {
            EmployerType::COMPANY => $request->validate([
                'company_name' => ['sometimes', 'required', 'string', 'max:255'],
                // Correctable: a mistyped TIN would otherwise be a
                // profile nobody can ever get approved.
                'tin' => ['sometimes', 'required', 'string', 'regex:/^\d{9}(\d{3})?$/'],
                'industry' => ['sometimes', 'required', 'string', 'max:255'],
                'location' => ['sometimes', 'required', 'string', 'max:255'],
                'location_id' => ['nullable', 'exists:locations,id'],
                'latitude' => ['nullable', 'numeric', 'between:-90,90'],
                'longitude' => ['nullable', 'numeric', 'between:-180,180'],
                'website' => ['nullable', 'url', 'max:255'],
                'description' => ['nullable', 'string', 'max:2000'],
            ]),
            EmployerType::INDIVIDUAL => $request->validate([
                'location' => ['sometimes', 'required', 'string', 'max:255'],
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

        /*
            The same exclusivity rule, on the way in through this endpoint.

            Creation checks it, and this did not. A profile made before
            employer_type existed still accepts one here, so a worker account
            holding one of those could set it to company and end up in exactly
            the state the other guard refuses to create - a verified-business
            badge on somebody who is also a tradesperson.
        */
        if (($validated['employer_type'] ?? null) === EmployerType::COMPANY->value
            && $user->isWorker()) {
            return $this->fail(
                'This account has a worker profile, so the employer side has '
                . 'to stay Individual. Business accounts cannot also look for '
                . 'work.',
                422
            );
        }

        // Digits only, the same as creating one does.
        if (isset($validated['tin'])) {
            $validated['tin'] = EmployerProfile::normaliseTin($validated['tin']);
        }

        $profile->update($validated);

        // Get verification status
        /*
            One person lives in one place. See SharedIdentity: a hybrid
            account used to keep two locations, so moving town on one side
            left the other advertising the old one.
        */
        app(\App\Services\SharedIdentity::class)->spreadLocation(
            $user,
            $profile->location,
            $profile->location_id,
            $profile->latitude === null ? null : (float) $profile->latitude,
            $profile->longitude === null ? null : (float) $profile->longitude,
        );

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
            // The posts belong to the account, not the profile, so they
            // would outlive it: live posts with no employer behind them.
            $live = $user->postedJobs()->whereIn('status', ['open', 'in_progress'])->count();

            if ($live > 0) {
                return $this->fail("Close your {$live} open job post" . ($live === 1 ? '' : 's') . ' first.', 422);
            }

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

        /*
            And the account's picture, so this is the face everywhere.

            The worker upload has always written users.avatar; this one did
            not, so a person who changed their employer picture kept their
            old photo in chat, on job cards and on the account screen, all
            of which read the account. One upload, one picture.
        */
        $user->forceFill(['avatar' => $path])->save();

        // Refresh profile to get updated data
        $profile = $profile->fresh();

        // Get verification status
        /*
            One person lives in one place. See SharedIdentity: a hybrid
            account used to keep two locations, so moving town on one side
            left the other advertising the old one.
        */
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
            // The job each review was for - same reason as the worker side.
            ->with(['reviewer:id,name', 'job:id,title,category_id', 'job.category:id,name'])
            ->latest()
            ->limit(20)
            ->get();

        return $this->ok([
            'user_id'        => $user->id,
            'name'           => $user->name,
            'avatar'         => $user->resolvedAvatarUrl(),
            'is_verified'    => (bool) $user->is_verified,
            'verification_state' => $user->verification_state,
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
            // Derived per request; see BadgeService for why there is no table.
            'badges'         => app(\App\Services\BadgeService::class)->forEmployer($user),
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
                'job_title' => $r->job?->title,
                'job_category' => $r->job?->category?->name,
            ])->values(),
        ]);
    }
}
