<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\EmployerType;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreEmployerProfileRequest;
use App\Http\Requests\UpdateCompanyProfileRequest;
use App\Http\Requests\UpdateIndividualProfileRequest;
use App\Http\Resources\EmployerProfileResource;
use App\Http\Resources\EmployerVerificationResource;
use App\Models\EmployerProfile;
use App\Services\EmployerVerificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

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

        // Check if profile already exists
        if ($user->employerProfile) {
            return $this->fail('Employer profile already exists. Use PUT to update.', 422);
        }

        $validated = $request->validated();

        // Create profile with transaction safety
        $profile = \DB::transaction(function () use ($user, $validated) {
            $user->forceFill(['user_type' => 'employer'])->save();

            return EmployerProfile::create([
                'user_id' => $user->id,
                'employer_type' => $validated['employer_type'],
                'company_name' => $validated['company_name'] ?? null,
                'industry' => $validated['industry'] ?? null,
                'website' => $validated['website'] ?? null,
                'description' => $validated['description'] ?? null,
                'location' => $validated['location'],
            ]);
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
        $validated = match($profile->employer_type) {
            EmployerType::COMPANY => $request->validate([
                'company_name' => ['required', 'string', 'max:255'],
                'industry' => ['required', 'string', 'max:255'],
                'location' => ['required', 'string', 'max:255'],
                'website' => ['nullable', 'url', 'max:255'],
                'description' => ['nullable', 'string', 'max:2000'],
            ]),
            EmployerType::INDIVIDUAL => $request->validate([
                'location' => ['required', 'string', 'max:255'],
                'description' => ['nullable', 'string', 'max:2000'],
            ]),
            default => throw new \InvalidArgumentException('Invalid employer type'),
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
            Storage::disk('public')->delete($profile->image_path);
        }

        // Store new image
        $path = $request->file('image')->store('employer_images', 'public');
        
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
}

