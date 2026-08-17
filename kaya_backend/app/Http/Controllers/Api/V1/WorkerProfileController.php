<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Models\WorkerCertification;
use App\Models\WorkerLicense;
use App\Models\WorkerLicenseExamination;
use App\Models\WorkerExperience;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class WorkerProfileController extends Controller
{
    // ==================== SETUP COMPLETION ====================
    
    public function completeSetup(Request $request)
    {
        $user = $request->user();
        $profile = WorkerProfile::where('user_id', $user->id)->first();
        
        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Worker profile not found',
                'data' => null
            ], 404);
        }
        
        $profile->setup_completed = true;
        $profile->save();
        
        return response()->json([
            'success' => true,
            'data' => ['setup_completed' => true],
            'message' => 'Profile setup completed successfully'
        ]);
    }
    
    public function deleteProfile(Request $request)
    {
        $user = $request->user();
        $profile = WorkerProfile::where('user_id', $user->id)->first();
        
        // Silent success if no profile exists
        if ($profile) {
            // The sub-records key off user_id, not worker_profile_id, so deleting
            // the profile row cascades nothing. They must go explicitly, or a
            // delete-then-recreate leaves the new profile carrying stale data.
            DB::transaction(function () use ($user, $profile) {
                WorkerSkill::where('user_id', $user->id)->delete();
                WorkerExperience::where('user_id', $user->id)->delete();
                WorkerCertification::where('user_id', $user->id)->delete();
                WorkerLicense::where('user_id', $user->id)->delete();
                WorkerLicenseExamination::where('user_id', $user->id)->delete();
                $profile->delete();
            });
        }

        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Profile deleted successfully'
        ]);
    }
    
    // ==================== BASIC PROFILE ====================
    
    public function updateBasicInfo(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'nullable|string|max:255',
            'city' => 'nullable|string|max:255',
            'phone' => 'nullable|string|max:20',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $user = $request->user();
        
        if ($request->filled('name')) {
            $user->name = $request->name;
        }
        
        if ($request->filled('city')) {
            $user->city = $request->city;
        }
        
        if ($request->filled('phone')) {
            $user->phone = $request->phone;
        }
        
        $user->save();

        $profile = WorkerProfile::firstOrCreate(
            ['user_id' => $user->id],
            [
                'availability_status' => 'available',
                'verification_status' => 'unverified',
                'setup_completed' => false,
            ]
        );

        if ($request->filled('city')) {
            $profile->location = $request->city;
            $profile->save();
        }
        
        return response()->json([
            'success' => true,
            'data' => [
                'name' => $user->name,
                'city' => $user->city,
                'phone' => $user->phone,
                'email' => $user->email,
            ],
            'message' => 'Profile updated successfully'
        ]);
    }
    
    public function uploadPhoto(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'photo' => 'required|image|mimes:jpeg,jpg,png|max:5120', // 5MB max
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $user = $request->user();
        
        // Delete old photo if exists
        if ($user->avatar && \Storage::disk('public')->exists($user->avatar)) {
            \Storage::disk('public')->delete($user->avatar);
        }
        
        // Store new photo
        $path = $request->file('photo')->store('profile_photos', 'public');
        $user->avatar = $path;
        $user->save();

        WorkerProfile::updateOrCreate(
            ['user_id' => $user->id],
            [
                'profile_photo_path' => $path,
                'availability_status' => 'available',
                'verification_status' => 'unverified',
            ]
        );
        
        return response()->json([
            'success' => true,
            'data' => [
                'photo_path' => $path,
                'photo_url' => asset('storage/' . $path),
            ],
            'message' => 'Photo uploaded successfully'
        ]);
    }
    
    // ==================== SKILLS ====================
    
    public function getSkills(Request $request)
    {
        $skills = WorkerSkill::with('category:id,name')
            ->where('user_id', $request->user()->id)
            ->get()
            ->map(function ($skill) {
                $categoryName = null;
                
                // If category_id exists, use it
                if ($skill->category_id && $skill->category) {
                    $categoryName = $skill->category->name;
                }
                // Otherwise, try to find the skill in master skills table by name
                elseif ($skill->skill_name) {
                    $masterSkill = \App\Models\Skill::with('category')
                        ->whereRaw('LOWER(name) = ?', [strtolower($skill->skill_name)])
                        ->first();
                    if ($masterSkill && $masterSkill->category) {
                        $categoryName = $masterSkill->category->name;
                    }
                }
                
                return [
                    'id' => $skill->id,
                    'user_id' => $skill->user_id,
                    'skill_name' => $skill->skill_name,
                    'proficiency_level' => $skill->proficiency_level,
                    'years_of_experience' => $skill->years_of_experience,
                    'category_id' => $skill->category_id,
                    'skill_id' => $skill->skill_id,
                    'category_name' => $categoryName,
                    'created_at' => $skill->created_at,
                    'updated_at' => $skill->updated_at,
                ];
            });
        
        return response()->json([
            'success' => true,
            'data' => $skills,
            'message' => 'Skills retrieved successfully'
        ]);
    }
    
    public function addSkill(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'skill_name' => 'required|string|max:255',
            'proficiency_level' => 'required|in:beginner,intermediate,advanced,expert',
            'years_of_experience' => 'required|integer|min:0',
            'category_id' => 'nullable|exists:categories,id',
            'skill_id' => 'nullable|exists:skills,id',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        // Check for duplicate skill (case-insensitive)
        $existing = WorkerSkill::where('user_id', $request->user()->id)
            ->whereRaw('LOWER(skill_name) = ?', [strtolower($request->skill_name)])
            ->first();
            
        if ($existing) {
            return response()->json([
                'success' => false,
                'message' => 'You already have this skill in your profile',
                'data' => null
            ], 422);
        }
        
        $skill = WorkerSkill::create([
            'user_id' => $request->user()->id,
            'skill_name' => $request->skill_name,
            'proficiency_level' => $request->proficiency_level,
            'years_of_experience' => $request->years_of_experience,
            'category_id' => $request->category_id,
            'skill_id' => $request->skill_id,
        ]);

        $profile = WorkerProfile::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'availability_status' => 'available',
                'verification_status' => 'unverified',
            ]
        );

        if ($request->filled('category_id') && $profile->category_id === null) {
            $profile->category_id = $request->category_id;
            $profile->save();
        }
        
        return response()->json([
            'success' => true,
            'data' => $skill,
            'message' => 'Skill added successfully'
        ], 201);
    }
    
    public function updateSkill(Request $request, $id)
    {
        $skill = WorkerSkill::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$skill) {
            return response()->json([
                'success' => false,
                'message' => 'Skill not found',
                'data' => null
            ], 404);
        }
        
        $validator = Validator::make($request->all(), [
            'skill_name' => 'required|string|max:255',
            'proficiency_level' => 'required|in:beginner,intermediate,advanced,expert',
            'years_of_experience' => 'required|integer|min:0',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $skill->update($request->only(['skill_name', 'proficiency_level', 'years_of_experience']));
        
        return response()->json([
            'success' => true,
            'data' => $skill,
            'message' => 'Skill updated successfully'
        ]);
    }
    
    public function deleteSkill(Request $request, $id)
    {
        $skill = WorkerSkill::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$skill) {
            return response()->json([
                'success' => false,
                'message' => 'Skill not found',
                'data' => null
            ], 404);
        }
        
        $skill->delete();
        
        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Skill deleted successfully'
        ]);
    }
    
    // ==================== CERTIFICATIONS ====================
    
    public function getCertifications(Request $request)
    {
        $certifications = WorkerCertification::where('user_id', $request->user()->id)->get();
        
        return response()->json([
            'success' => true,
            'data' => $certifications,
            'message' => 'Certifications retrieved successfully'
        ]);
    }
    
    public function addCertification(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'certification_name' => 'required|string|max:255',
            'issuing_organization' => 'required|string|max:255',
            'issue_date' => 'nullable|date|before_or_equal:today',
            'expiry_date' => 'nullable|date|after:issue_date',
            'credential_id' => 'nullable|string|max:255',
            'document' => 'nullable|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $data = [
            'user_id' => $request->user()->id,
            'certification_name' => $request->certification_name,
            'issuing_organization' => $request->issuing_organization,
            'issue_date' => $request->issue_date,
            'expiry_date' => $request->expiry_date,
            'credential_id' => $request->credential_id,
        ];
        
        // Handle file upload
        if ($request->hasFile('document')) {
            $path = $request->file('document')->store('certifications', 'public');
            $data['document_path'] = $path;
        }
        
        $certification = WorkerCertification::create($data);
        
        return response()->json([
            'success' => true,
            'data' => $certification,
            'message' => 'Certification added successfully'
        ], 201);
    }
    
    public function updateCertification(Request $request, $id)
    {
        $certification = WorkerCertification::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$certification) {
            return response()->json([
                'success' => false,
                'message' => 'Certification not found',
                'data' => null
            ], 404);
        }
        
        $validator = Validator::make($request->all(), [
            'certification_name' => 'required|string|max:255',
            'issuing_organization' => 'required|string|max:255',
            'issue_date' => 'nullable|date|before_or_equal:today',
            'expiry_date' => 'nullable|date|after:issue_date',
            'credential_id' => 'nullable|string|max:255',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $certification->update($request->only(['certification_name', 'issuing_organization', 'issue_date', 'expiry_date', 'credential_id']));
        
        return response()->json([
            'success' => true,
            'data' => $certification,
            'message' => 'Certification updated successfully'
        ]);
    }
    
    public function deleteCertification(Request $request, $id)
    {
        $certification = WorkerCertification::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$certification) {
            return response()->json([
                'success' => false,
                'message' => 'Certification not found',
                'data' => null
            ], 404);
        }
        
        $certification->delete();
        
        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Certification deleted successfully'
        ]);
    }
    
    // ==================== LICENSES ====================
    
    public function getLicenses(Request $request)
    {
        $licenses = WorkerLicense::where('user_id', $request->user()->id)->get();
        
        return response()->json([
            'success' => true,
            'data' => $licenses,
            'message' => 'Licenses retrieved successfully'
        ]);
    }
    
    public function addLicense(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'license_name' => 'required|string|max:255',
            'license_number' => 'required|string|max:255',
            'issuing_authority' => 'required|string|max:255',
            'issue_date' => 'nullable|date|before_or_equal:today',
            'expiry_date' => 'nullable|date|after:issue_date',
            'document' => 'nullable|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $data = [
            'user_id' => $request->user()->id,
            'license_name' => $request->license_name,
            'license_number' => $request->license_number,
            'issuing_authority' => $request->issuing_authority,
            'issue_date' => $request->issue_date,
            'expiry_date' => $request->expiry_date,
        ];
        
        // Handle file upload
        if ($request->hasFile('document')) {
            $path = $request->file('document')->store('licenses', 'public');
            $data['document_path'] = $path;
        }
        
        $license = WorkerLicense::create($data);
        
        return response()->json([
            'success' => true,
            'data' => $license,
            'message' => 'License added successfully'
        ], 201);
    }
    
    public function updateLicense(Request $request, $id)
    {
        $license = WorkerLicense::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$license) {
            return response()->json([
                'success' => false,
                'message' => 'License not found',
                'data' => null
            ], 404);
        }
        
        $validator = Validator::make($request->all(), [
            'license_name' => 'required|string|max:255',
            'license_number' => 'required|string|max:255',
            'issuing_authority' => 'required|string|max:255',
            'issue_date' => 'nullable|date|before_or_equal:today',
            'expiry_date' => 'nullable|date|after:issue_date',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $license->update($request->only(['license_name', 'license_number', 'issuing_authority', 'issue_date', 'expiry_date']));
        
        return response()->json([
            'success' => true,
            'data' => $license,
            'message' => 'License updated successfully'
        ]);
    }
    
    public function deleteLicense(Request $request, $id)
    {
        $license = WorkerLicense::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$license) {
            return response()->json([
                'success' => false,
                'message' => 'License not found',
                'data' => null
            ], 404);
        }
        
        $license->delete();
        
        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'License deleted successfully'
        ]);
    }
    
    // ==================== EXPERIENCES ====================
    
    public function getExperiences(Request $request)
    {
        $experiences = WorkerExperience::where('user_id', $request->user()->id)
            ->orderBy('start_date', 'desc')
            ->get();
        
        return response()->json([
            'success' => true,
            'data' => $experiences,
            'message' => 'Experiences retrieved successfully'
        ]);
    }
    
    public function addExperience(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'job_title' => 'required|string|max:255',
            'company_name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'start_date' => 'required|date|before_or_equal:today',
            'end_date' => 'nullable|date|after_or_equal:start_date|before_or_equal:today',
            'is_current' => 'nullable|boolean',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $experience = WorkerExperience::create([
            'user_id' => $request->user()->id,
            'job_title' => $request->job_title,
            'company_name' => $request->company_name,
            'description' => $request->description,
            'start_date' => $request->start_date,
            'end_date' => $request->end_date,
            'is_current' => $request->is_current ?? false,
        ]);
        
        return response()->json([
            'success' => true,
            'data' => $experience,
            'message' => 'Experience added successfully'
        ], 201);
    }
    
    public function updateExperience(Request $request, $id)
    {
        $experience = WorkerExperience::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$experience) {
            return response()->json([
                'success' => false,
                'message' => 'Experience not found',
                'data' => null
            ], 404);
        }
        
        $validator = Validator::make($request->all(), [
            'job_title' => 'required|string|max:255',
            'company_name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'start_date' => 'required|date|before_or_equal:today',
            'end_date' => 'nullable|date|after_or_equal:start_date|before_or_equal:today',
            'is_current' => 'nullable|boolean',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $experience->update($request->only(['job_title', 'company_name', 'description', 'start_date', 'end_date', 'is_current']));
        
        return response()->json([
            'success' => true,
            'data' => $experience,
            'message' => 'Experience updated successfully'
        ]);
    }
    
    public function deleteExperience(Request $request, $id)
    {
        $experience = WorkerExperience::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$experience) {
            return response()->json([
                'success' => false,
                'message' => 'Experience not found',
                'data' => null
            ], 404);
        }
        
        $experience->delete();
        
        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Experience deleted successfully'
        ]);
    }
    
    // ==================== LICENSE EXAMINATIONS ====================
    
    public function getLicenseExaminations(Request $request)
    {
        $examinations = WorkerLicenseExamination::where('user_id', $request->user()->id)->get();
        
        return response()->json([
            'success' => true,
            'data' => $examinations,
            'message' => 'License examinations retrieved successfully'
        ]);
    }
    
    public function addLicenseExamination(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'exam_name' => 'required|string|max:255',
            'exam_date' => 'nullable|date|before_or_equal:today',
            'passing_score' => 'nullable|numeric|min:0|max:100',
            'actual_score' => 'nullable|numeric|min:0|max:100',
            'status' => 'required|in:passed,failed,pending',
            'certificate_number' => 'nullable|string|max:255',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $examination = WorkerLicenseExamination::create([
            'user_id' => $request->user()->id,
            'exam_name' => $request->exam_name,
            'exam_date' => $request->exam_date,
            'passing_score' => $request->passing_score,
            'actual_score' => $request->actual_score,
            'status' => $request->status,
            'certificate_number' => $request->certificate_number,
        ]);
        
        return response()->json([
            'success' => true,
            'data' => $examination,
            'message' => 'License examination added successfully'
        ], 201);
    }
    
    public function updateLicenseExamination(Request $request, $id)
    {
        $examination = WorkerLicenseExamination::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$examination) {
            return response()->json([
                'success' => false,
                'message' => 'License examination not found',
                'data' => null
            ], 404);
        }
        
        $validator = Validator::make($request->all(), [
            'exam_name' => 'required|string|max:255',
            'exam_date' => 'nullable|date|before_or_equal:today',
            'passing_score' => 'nullable|numeric|min:0|max:100',
            'actual_score' => 'nullable|numeric|min:0|max:100',
            'status' => 'required|in:passed,failed,pending',
            'certificate_number' => 'nullable|string|max:255',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $examination->update($request->only(['exam_name', 'exam_date', 'passing_score', 'actual_score', 'status', 'certificate_number']));
        
        return response()->json([
            'success' => true,
            'data' => $examination,
            'message' => 'License examination updated successfully'
        ]);
    }
    
    public function deleteLicenseExamination(Request $request, $id)
    {
        $examination = WorkerLicenseExamination::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->first();
            
        if (!$examination) {
            return response()->json([
                'success' => false,
                'message' => 'License examination not found',
                'data' => null
            ], 404);
        }
        
        $examination->delete();
        
        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'License examination deleted successfully'
        ]);
    }

    // ==================== BROWSE (employer-facing directory) ====================

    /**
     * GET /workers
     *
     * Public worker directory for the employer-mode home feed and search.
     * Only profiles that have finished onboarding are listed — an incomplete
     * profile has nothing an employer could act on.
     */
    public function browse(Request $request)
    {
        $data = $request->validate([
            'q'           => ['nullable', 'string', 'max:100'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'skill_id'    => ['nullable', 'integer', 'exists:skills,id'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'per_page'    => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $query = WorkerProfile::query()
            ->with(['user:id,name,avatar,is_verified,city', 'skills', 'category:id,name'])
            ->whereNotNull('category_id')
            ->whereNotNull('location');

        if (!empty($data['category_id'])) {
            $query->where('category_id', $data['category_id']);
        }

        if (!empty($data['location_id'])) {
            $query->where('location_id', $data['location_id']);
        }

        if (!empty($data['skill_id'])) {
            $query->whereHas('skills', fn ($q) => $q->where('skill_id', $data['skill_id']));
        }

        if (!empty($data['q'])) {
            $term = $data['q'];
            $query->where(function ($q) use ($term) {
                $q->whereHas('user', fn ($u) => $u->where('name', 'like', "%{$term}%"))
                    ->orWhereHas('skills', fn ($s) => $s->where('skill_name', 'like', "%{$term}%"))
                    ->orWhereHas('category', fn ($c) => $c->where('name', 'like', "%{$term}%"));
            });
        }

        // isSetupCompleted() requires at least one skill row, so this eager-loads
        // the same relation the filter checks — no extra query per row.
        $profiles = $query->get()->filter(fn (WorkerProfile $p) => $p->isSetupCompleted());

        $perPage = $data['per_page'] ?? 20;
        $page = (int) $request->input('page', 1);
        $paged = $profiles->forPage($page, $perPage)->values();

        return response()->json([
            'success' => true,
            'data' => [
                'data' => $paged->map(fn (WorkerProfile $p) => [
                    'user_id'      => $p->user_id,
                    'name'         => $p->user?->name,
                    'avatar'       => $p->user?->avatar,
                    'is_verified'  => (bool) $p->user?->is_verified,
                    'location'     => $p->location,
                    'location_id'  => $p->location_id,
                    'category'     => $p->category?->name,
                    'category_id'  => $p->category_id,
                    'bio'          => $p->bio,
                    'rating_avg'   => $p->rating_avg,
                    'rating_count' => $p->rating_count,
                    'skills'       => $p->skills->pluck('skill_name')->filter()->values(),
                    'availability_status' => $p->availability_status,
                ]),
                'current_page' => $page,
                'per_page'     => $perPage,
                'total'        => $profiles->count(),
            ],
            'message' => 'Success',
        ]);
    }

    /**
     * GET /workers/{user}
     *
     * Full public profile — everything WorkerProfileScreen shows an employer:
     * bio, skills, experience, certifications, and reviews received. Only a
     * profile that has finished onboarding is shown; a half-set-up profile has
     * nothing an employer could evaluate.
     */
    public function show(Request $request, \App\Models\User $user)
    {
        $profile = $user->workerProfile;

        if (!$profile || !$profile->isSetupCompleted()) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Worker profile not found',
            ], 404);
        }

        $profile->load([
            'skills', 'experiences', 'certifications', 'licenses',
            'licenseExaminations', 'category',
        ]);

        $reviews = \App\Models\Review::where('reviewee_id', $user->id)
            ->with('reviewer:id,name')
            ->latest()
            ->limit(20)
            ->get();

        // Credentials are only worth anything to an employer if the supporting
        // document is actually viewable — a claimed license with no scan is
        // just a text field. Resolve every stored path to an absolute URL.
        $docUrl = fn (?string $path) => $path
            ? \Illuminate\Support\Facades\Storage::disk('public')->url($path)
            : null;

        $year = fn ($date) => $date
            ? \Illuminate\Support\Carbon::parse($date)->format('Y')
            : null;

        return response()->json([
            'success' => true,
            'data' => [
                'user_id'             => $user->id,
                'name'                => $user->name,
                // The worker's own uploaded photo takes precedence; users.avatar
                // is the fallback (Google sign-in populates that one).
                'avatar'              => $docUrl($profile->profile_photo_path)
                                          ?? $docUrl($user->avatar),
                'is_verified'         => (bool) $user->is_verified,
                'verification_status' => $profile->verification_status,
                'location'            => $profile->location,
                'category'            => $profile->category?->name,
                'category_id'         => $profile->category_id,
                'bio'                 => $profile->bio,
                'availability_status' => $profile->availability_status,
                'rating_avg'          => $profile->rating_avg,
                'rating_count'        => $profile->rating_count,

                // Skills carry proficiency and years — an employer choosing
                // between two masons needs those, not just the label.
                'skills'              => $profile->skills->map(fn ($s) => [
                    'name'                => $s->skill_name,
                    'proficiency_level'   => $s->proficiency_level,
                    'years_of_experience' => $s->years_of_experience,
                ])->values(),

                'experiences'         => $profile->experiences->map(fn ($e) => [
                    'title'       => $e->job_title,
                    'company'     => $e->company_name,
                    'start_date'  => $e->start_date,
                    'end_date'    => $e->end_date,
                    'is_current'  => (bool) $e->is_current,
                    'description' => $e->description,
                ])->values(),

                'certifications'      => $profile->certifications->map(fn ($c) => [
                    'title'         => $c->certification_name,
                    'issuer'        => $c->issuing_organization,
                    'year'          => $year($c->issue_date),
                    'issue_date'    => $c->issue_date,
                    'expiry_date'   => $c->expiry_date,
                    'credential_id' => $c->credential_id,
                    'document_url'  => $docUrl($c->document_path),
                ])->values(),

                // Licenses and license examinations were absent from this
                // endpoint entirely — the two credential types that matter most
                // for trades work never reached the public profile at all.
                'licenses'            => $profile->licenses->map(fn ($l) => [
                    'name'         => $l->license_name,
                    'number'       => $l->license_number,
                    'authority'    => $l->issuing_authority,
                    'issue_date'   => $l->issue_date,
                    'expiry_date'  => $l->expiry_date,
                    'document_url' => $docUrl($l->document_path),
                ])->values(),

                'license_examinations' => $profile->licenseExaminations->map(fn ($e) => [
                    'name'               => $e->exam_name,
                    'exam_date'          => $e->exam_date,
                    'passing_score'      => $e->passing_score,
                    'actual_score'       => $e->actual_score,
                    'status'             => $e->status,
                    'certificate_number' => $e->certificate_number,
                    'document_url'       => $docUrl($e->document_path),
                ])->values(),

                'reviews'             => $reviews->map(fn ($r) => [
                    'reviewer' => $r->reviewer?->name,
                    'rating'   => $r->rating,
                    'date'     => $r->created_at?->diffForHumans(),
                    'comment'  => $r->comment,
                ])->values(),
            ],
            'message' => 'Success',
        ]);
    }
}
