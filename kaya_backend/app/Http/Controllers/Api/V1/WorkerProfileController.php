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
use Illuminate\Support\Facades\Storage;
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
            // Structured location from the PSGC picker. Without these the
            // profile only ever stored the display string, so a worker had no
            // coordinates and every distance/proximity figure came out null.
            'location_id' => 'nullable|integer|exists:locations,id',
            'latitude'    => 'nullable|numeric|between:-90,90',
            'longitude'   => 'nullable|numeric|between:-180,180',
            // What the worker charges. gte:rate_min rejects an inverted range,
            // which would otherwise be stored happily and then break every pay
            // filter — the same rule jobs already apply to budget_max.
            'rate_min'           => 'nullable|numeric|min:0',
            'rate_max'           => 'nullable|numeric|min:0|gte:rate_min',
            'rate_unit'          => 'nullable|in:hour,day,project',
            'is_rate_negotiable' => 'nullable|boolean',
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

        $profileDirty = false;

        if ($request->filled('city')) {
            $profile->location = $request->city;
            $profileDirty = true;
        }

        foreach (['location_id', 'latitude', 'longitude', 'rate_min', 'rate_max', 'rate_unit'] as $field) {
            if ($request->filled($field)) {
                $profile->{$field} = $request->input($field);
                $profileDirty = true;
            }
        }

        // has() not filled(): `false` is a real value here, and filled() would
        // treat turning the flag off as "not sent" and silently keep it on.
        if ($request->has('is_rate_negotiable')) {
            $profile->is_rate_negotiable = $request->boolean('is_rate_negotiable');
            $profileDirty = true;
        }

        if ($profileDirty) {
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
        if ($user->avatar && \Storage::disk(config('filesystems.media'))->exists($user->avatar)) {
            \Storage::disk(config('filesystems.media'))->delete($user->avatar);
        }
        
        // Store new photo
        $path = $request->file('photo')->store('profile_photos', config('filesystems.media'));
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
            // Optional, because the app has no screen that asks for them.
            //
            // These were required, so the client invented values to satisfy the
            // rule — every skill was sent as "intermediate, 1 year" regardless
            // of the worker. The public profile showed that back to employers
            // as if the worker had claimed it, which is worse than showing
            // nothing: it is a fabricated credential on a hiring platform.
            // Null means "not stated" and renders as nothing.
            'proficiency_level' => 'nullable|in:beginner,intermediate,advanced,expert',
            'years_of_experience' => 'nullable|integer|min:0',
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
            // Optional, because the app has no screen that asks for them.
            //
            // These were required, so the client invented values to satisfy the
            // rule — every skill was sent as "intermediate, 1 year" regardless
            // of the worker. The public profile showed that back to employers
            // as if the worker had claimed it, which is worse than showing
            // nothing: it is a fabricated credential on a hiring platform.
            // Null means "not stated" and renders as nothing.
            'proficiency_level' => 'nullable|in:beginner,intermediate,advanced,expert',
            'years_of_experience' => 'nullable|integer|min:0',
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
            $path = $request->file('document')->store('certifications', config('filesystems.media'));
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
        
        // Same omission as licences above: the replacement file was sent and
        // silently dropped.
        $data = $request->only(['certification_name', 'issuing_organization', 'issue_date', 'expiry_date', 'credential_id']);
        $previous = null;

        if ($request->hasFile('document')) {
            $previous = $certification->document_path;
            $data['document_path'] = $request->file('document')
                ->store('certifications', config('filesystems.media'));
        }

        $certification->update($data);

        if ($previous !== null && $previous !== $certification->document_path) {
            Storage::disk(config('filesystems.media'))->delete($previous);
        }
        
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
            $path = $request->file('document')->store('licenses', config('filesystems.media'));
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
            'document' => 'nullable|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }

        /*
            The document was not editable.

            Adding a licence accepts a file; updating one never did, and the
            client sent the replacement anyway. So somebody who noticed they
            had uploaded the wrong scan could pick a new one, be told it saved,
            and keep the old file forever with no way to correct it.

            The old file is deleted after the row is updated rather than
            before, so a failed write cannot leave a row pointing at a file
            that is already gone.
        */
        $data = $request->only(['license_name', 'license_number', 'issuing_authority', 'issue_date', 'expiry_date']);
        $previous = null;

        if ($request->hasFile('document')) {
            $previous = $license->document_path;
            $data['document_path'] = $request->file('document')
                ->store('licenses', config('filesystems.media'));
        }

        $license->update($data);

        if ($previous !== null && $previous !== $license->document_path) {
            Storage::disk(config('filesystems.media'))->delete($previous);
        }
        
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
            // Pay filtering. A worker with no rate on file is kept when no
            // bound is given and dropped when one is — an unstated rate cannot
            // be claimed to fall inside a range.
            'rate_min'    => ['nullable', 'numeric', 'min:0'],
            'rate_max'    => ['nullable', 'numeric', 'min:0'],
            'rate_unit'   => ['nullable', 'in:hour,day,project'],
            // Distance. Without it this endpoint returned every worker in the
            // country while the screen above it said "near you".
            'radius_km'   => ['nullable', 'numeric', 'min:1', 'max:500'],
        ]);

        $query = WorkerProfile::query()
            // psgcLocation (not location — that's a string column on this
            // table) supplies the town centroid for the distance figure.
            ->with(['user:id,name,avatar,is_verified,city', 'skills', 'category:id,name', 'psgcLocation'])
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

        // Rate is a column, so it filters in the database rather than after.
        if (!empty($data['rate_unit'])) {
            $query->where('rate_unit', $data['rate_unit']);
        }
        if (isset($data['rate_min'])) {
            // Their top rate must reach what the employer is willing to pay
            // from; a worker asking more than the ceiling is excluded below.
            $query->whereNotNull('rate_min')
                ->where(fn ($q) => $q->where('rate_max', '>=', $data['rate_min'])
                    ->orWhere(fn ($q2) => $q2->whereNull('rate_max')
                        ->where('rate_min', '>=', $data['rate_min'])));
        }
        if (isset($data['rate_max'])) {
            $query->whereNotNull('rate_min')->where('rate_min', '<=', $data['rate_max']);
        }

        // isSetupCompleted() requires at least one skill row, so this eager-loads
        // the same relation the filter checks — no extra query per row.
        $profiles = $query->get()->filter(fn (WorkerProfile $p) => $p->isSetupCompleted());

        // Where the person browsing is, so each worker can carry a real
        // "x km away" instead of the employer guessing from a place name.
        [$viewerLat, $viewerLng] = $this->viewerCoords($request);

        /*
            Distance filtering and ordering.

            Applied here rather than in SQL because the distance comes from
            workerDistance(), which falls back through the profile's own
            coordinates to its PSGC town centroid. Expressing that fallback as
            a query expression would duplicate the rule in two places.

            A worker whose distance cannot be computed at all is kept when no
            radius was asked for, and dropped when one was — "within 10 km"
            cannot honestly include someone whose position is unknown.
        */
        $withDistance = $profiles->map(function (WorkerProfile $p) use ($viewerLat, $viewerLng) {
            $p->setAttribute('computed_distance_km', $this->workerDistance($p, $viewerLat, $viewerLng));
            return $p;
        });

        if (!empty($data['radius_km'])) {
            $withDistance = $withDistance->filter(
                fn (WorkerProfile $p) => $p->computed_distance_km !== null
                    && $p->computed_distance_km <= $data['radius_km']
            );
        }

        // Nearest first whenever the viewer has a position at all.
        if ($viewerLat !== null && $viewerLng !== null) {
            $withDistance = $withDistance->sortBy(
                fn (WorkerProfile $p) => $p->computed_distance_km ?? PHP_FLOAT_MAX
            );
        }

        $profiles = $withDistance->values();

        $perPage = $data['per_page'] ?? 20;
        $page = (int) $request->input('page', 1);
        $paged = $profiles->forPage($page, $perPage)->values();

        return response()->json([
            'success' => true,
            'data' => [
                'data' => $paged->map(fn (WorkerProfile $p) => [
                    /*
                        Coarse on purpose.

                        This used to be the exact figure to 0.1 km, while the
                        viewer sets their own coordinates freely through
                        PUT /employer-profile. Reading the distance from three
                        chosen positions puts three circles on a map that
                        intersect at one point — the worker's home, to about a
                        hundred metres. show() deliberately withholds latitude
                        and longitude; this handed the same thing back as a
                        derived value.

                        Bucketed, it still answers the only question an
                        employer actually has — is this person near enough —
                        and the exact number stays server-side for the radius
                        filter and the sort above.
                    */
                    'distance_km'    => $this->bucketDistance($p->computed_distance_km),
                    'distance_label' => $this->distanceLabel($p->computed_distance_km),
                    'user_id'      => $p->user_id,
                    // What they charge. rate_label is the phrasing every
                    // surface should show; the raw numbers are there for
                    // filtering and for the edit form.
                    'rate_min'           => $p->rate_min,
                    'rate_max'           => $p->rate_max,
                    'rate_unit'          => $p->rate_unit,
                    'is_rate_negotiable' => $p->is_rate_negotiable,
                    'rate_label'         => $p->rateLabel(),
                    'name'         => $p->user?->name,
                    // Same resolver the profile screen uses — these two
                    // disagreed, so one account showed two different photos.
                    'avatar'       => $p->resolvedAvatarUrl(),
                    'is_verified'  => (bool) $p->user?->is_verified,
                    'location'     => $p->location,
                    'location_id'  => $p->location_id,
                    'category'     => $p->category?->name,
                    'category_id'  => $p->category_id,
                    'bio'          => $p->bio,
                    // Same cast as the single-profile view: decimal:2 would
                    // otherwise send the string "5.00" into a numeric field.
                    'rating_avg'   => (float) $p->rating_avg,
                    'rating_count' => (int) $p->rating_count,
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
     * Coordinates of whoever is browsing — their employer profile first (they
     * are hiring, so the job site is what matters), then their worker profile.
     *
     * @return array{0: ?float, 1: ?float}
     */
    private function viewerCoords(Request $request): array
    {
        $user = $request->user();
        if (!$user) return [null, null];

        foreach ([$user->employerProfile, $user->workerProfile] as $profile) {
            if (!$profile) continue;

            if ($profile->latitude !== null && $profile->longitude !== null) {
                return [(float) $profile->latitude, (float) $profile->longitude];
            }

            if ($profile->location_id) {
                $loc = \App\Models\Location::find($profile->location_id);
                if ($loc && $loc->latitude !== null) {
                    return [(float) $loc->latitude, (float) $loc->longitude];
                }
            }
        }

        return [null, null];
    }

    /** Rounded km between the viewer and this worker, or null if unknown. */
    /**
     * Rounds a distance down to a band before it leaves the server.
     *
     * Precision here is what makes trilateration possible — see the comment at
     * the call site. The bands widen with distance because that is where
     * precision stops being useful anyway: "3 km" and "3.4 km" mean the same
     * thing to someone deciding whether to hire.
     */
    private function bucketDistance(?float $km): ?float
    {
        if ($km === null) return null;

        if ($km < 1)  return 1;
        if ($km < 5)  return 5;
        if ($km < 15) return 15;
        if ($km < 30) return 30;
        if ($km < 50) return 50;

        return 100;
    }

    /** The band in words, so the app does not have to invent the phrasing. */
    private function distanceLabel(?float $km): ?string
    {
        if ($km === null) return null;

        if ($km < 1)  return 'Under 1 km away';
        if ($km < 5)  return 'Under 5 km away';
        if ($km < 15) return '5–15 km away';
        if ($km < 30) return '15–30 km away';
        if ($km < 50) return '30–50 km away';

        return 'Over 50 km away';
    }

    private function workerDistance(WorkerProfile $p, ?float $lat, ?float $lng): ?float
    {
        $wLat = $p->latitude !== null ? (float) $p->latitude : $p->psgcLocation?->latitude;
        $wLng = $p->longitude !== null ? (float) $p->longitude : $p->psgcLocation?->longitude;

        $km = \App\Services\JobMatchService::distanceBetween(
            $lat, $lng,
            $wLat === null ? null : (float) $wLat,
            $wLng === null ? null : (float) $wLng,
        );

        return $km === null ? null : round($km, 1);
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

        /*
            Count the view.

            Recorded after the 404 above, so opening a profile that does not
            exist is not counted as someone having looked at it. Self-views and
            repeat views on the same day are dropped inside the recorder.
        */
        app(\App\Services\ProfileViewRecorder::class)->record(
            viewer: $request->user(),
            viewed: $user,
            viewedAs: \App\Models\ProfileView::AS_WORKER,
            source: $request->query('source'),
        );

        $profile->load([
            'skills', 'experiences', 'certifications', 'licenses',
            'licenseExaminations', 'category',
        ]);

        // Their worker reviews only. A hybrid account's worker profile was
        // showing reviews written about them as an employer — see the mirror of
        // this in EmployerProfileController.
        $reviews = \App\Models\Review::where('reviewee_id', $user->id)
            ->where('reviewee_role', 'worker')
            ->with('reviewer:id,name')
            ->latest()
            ->limit(20)
            ->get();

        // Credentials are only worth anything to an employer if the supporting
        // document is actually viewable — a claimed license with no scan is
        // just a text field. Resolve every stored path to an absolute URL.
        /*
            Credential documents and licence numbers are not public.

            This endpoint is reachable by any authenticated account, and it was
            returning the raw `license_number` — for Philippine trades that is
            the PRC, TESDA or driver's licence number, a government identifier —
            alongside a permanent public URL to the scan. A licence scan
            typically carries a date of birth, a signature and a home address.
            Walking users.id harvested both for every worker on the platform.

            The reasoning for showing scans at all is sound: a claimed licence
            with no scan is just a text field. But that argument applies to an
            employer weighing a hire, not to every account in the app. Same
            entitlement rule as the resume — the owner, or an employer this
            worker has actually applied to.

            Everyone else still learns the credential exists, who issued it and
            when, which is what a public profile is for.
        */
        $viewer = $request->user();
        $canSeeDocuments = $viewer && (
            $viewer->id === $user->id
            || \App\Models\Application::where('worker_id', $user->id)
                ->whereHas('job', fn ($q) => $q->where('employer_id', $viewer->id))
                ->exists()
        );

        $docUrl = fn (?string $path) => ($path && $canSeeDocuments)
            ? \Illuminate\Support\Facades\Storage::disk(config('filesystems.media'))->url($path)
            : null;

        // So the profile can show "certificate on file" without leaking it.
        $hasDoc = fn (?string $path) => filled($path);

        /**
         * Masks a credential number for anyone not entitled to the document.
         *
         * The last four are kept so an employer who already holds a copy can
         * confirm they match, which is the only legitimate use for seeing it
         * before a hire.
         */
        $credentialNumber = function (?string $number) use ($canSeeDocuments) {
            if (blank($number) || $canSeeDocuments) return $number;

            return strlen($number) > 4
                ? str_repeat('•', max(strlen($number) - 4, 3)) . substr($number, -4)
                : '••••';
        };

        $year = fn ($date) => $date
            ? \Illuminate\Support\Carbon::parse($date)->format('Y')
            : null;

        return response()->json([
            'success' => true,
            'data' => [
                'user_id'             => $user->id,
                'name'                => $user->name,
                'avatar'              => $profile->resolvedAvatarUrl(),
                'is_verified'         => (bool) $user->is_verified,
                'verification_status' => $profile->verification_status,
                'location'            => $profile->location,
                'category'            => $profile->category?->name,
                'category_id'         => $profile->category_id,
                'bio'                 => $profile->bio,
                'availability_status' => $profile->availability_status,
                /*
                    Cast, because decimal:2 serialises as the STRING "5.00".

                    The employer endpoint returns a number for the same field,
                    so one account's two halves described their rating in two
                    different JSON types. Any client doing `as num` on this
                    throws — which is exactly how the applicants list went down
                    once already, on `worker_rating` arriving as "0.00".
                */
                'rating_avg'          => (float) $profile->rating_avg,
                'rating_count'        => $profile->rating_count,

                // What they charge. rate_label is the phrasing every surface
                // shows; the raw numbers are for the edit form and filtering.
                'rate_min'            => $profile->rate_min,
                'rate_max'            => $profile->rate_max,
                'rate_unit'           => $profile->rate_unit,
                'is_rate_negotiable'  => $profile->is_rate_negotiable,
                'rate_label'          => $profile->rateLabel(),

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
                    'credential_id' => $credentialNumber($c->credential_id),
                    'document_url'  => $docUrl($c->document_path),
                    'has_document'  => $hasDoc($c->document_path),
                ])->values(),

                // Licenses and license examinations were absent from this
                // endpoint entirely — the two credential types that matter most
                // for trades work never reached the public profile at all.
                'licenses'            => $profile->licenses->map(fn ($l) => [
                    'name'         => $l->license_name,
                    'number'       => $credentialNumber($l->license_number),
                    'authority'    => $l->issuing_authority,
                    'issue_date'   => $l->issue_date,
                    'expiry_date'  => $l->expiry_date,
                    'document_url' => $docUrl($l->document_path),
                    'has_document' => $hasDoc($l->document_path),
                ])->values(),

                'license_examinations' => $profile->licenseExaminations->map(fn ($e) => [
                    'name'               => $e->exam_name,
                    'exam_date'          => $e->exam_date,
                    'passing_score'      => $e->passing_score,
                    'actual_score'       => $e->actual_score,
                    'status'             => $e->status,
                    'certificate_number' => $credentialNumber($e->certificate_number),
                    'document_url'       => $docUrl($e->document_path),
                    'has_document'       => $hasDoc($e->document_path),
                ])->values(),

                'reviews'             => $reviews->map(fn ($r) => [
                    'reviewer' => $r->reviewer?->name,
                    'rating'   => $r->rating,
                    'date'     => $r->created_at?->diffForHumans(),
                    'comment'  => $r->comment,
                    'tags'     => $r->tags ?? [],
                ])->values(),
            ],
            'message' => 'Success',
        ]);
    }

    // ── Resume ──────────────────────────────────────────────────────────────

    /**
     * POST /worker/profile/resume
     *
     * Stored on the private disk, not `public`. Everything else this app
     * uploads — avatars, job photos — is world-readable by design. A resume is
     * not: it carries a phone number, a home address and a full employment
     * history, and a public storage URL is guessable and permanent. It is
     * served only through downloadResume(), which checks who is asking.
     */
    public function uploadResume(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // No images. A photo of a CV defeats the point for an employer
            // trying to read it, and lets someone upload arbitrary media here.
            'resume' => 'required|file|mimes:pdf,doc,docx|max:5120',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data'    => null,
            ], 422);
        }

        $profile = WorkerProfile::where('user_id', $request->user()->id)->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Set up your worker profile first',
                'data'    => null,
            ], 422);
        }

        // Replacing a resume removes the old file. Without this every re-upload
        // leaves an orphan on disk that nothing will ever reference or clean up.
        if ($profile->hasResume() && Storage::disk(config('filesystems.documents'))->exists($profile->resume_path)) {
            Storage::disk(config('filesystems.documents'))->delete($profile->resume_path);
        }

        $file = $request->file('resume');
        $path = $file->store('resumes', config('filesystems.documents'));

        $profile->update([
            'resume_path'          => $path,
            'resume_original_name' => $file->getClientOriginalName(),
            'resume_uploaded_at'   => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Resume uploaded',
            'data'    => $this->resumePayload($profile->fresh()),
        ]);
    }

    /** DELETE /worker/profile/resume */
    public function deleteResume(Request $request)
    {
        $profile = WorkerProfile::where('user_id', $request->user()->id)->first();

        if (!$profile || !$profile->hasResume()) {
            return response()->json([
                'success' => false,
                'message' => 'No resume to remove',
                'data'    => null,
            ], 404);
        }

        if (Storage::disk(config('filesystems.documents'))->exists($profile->resume_path)) {
            Storage::disk(config('filesystems.documents'))->delete($profile->resume_path);
        }

        $profile->update([
            'resume_path'          => null,
            'resume_original_name' => null,
            'resume_uploaded_at'   => null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Resume removed',
            'data'    => $this->resumePayload($profile->fresh()),
        ]);
    }

    /**
     * GET /workers/{user}/resume
     *
     * The access rule is the feature here. A resume is released to:
     *
     *   • the worker themselves, and
     *   • an employer the worker has actually applied to.
     *
     * Applying is the consent. Browsing the worker directory is not — otherwise
     * any account that can reach /workers could harvest home addresses and
     * phone numbers in bulk, which is exactly the abuse RA 10173 exists to
     * prevent.
     */
    public function downloadResume(Request $request, \App\Models\User $user)
    {
        $viewer  = $request->user();
        $profile = WorkerProfile::where('user_id', $user->id)->first();

        if (!$profile || !$profile->hasResume()) {
            return response()->json([
                'success' => false,
                'message' => 'This worker has no resume on file',
                'data'    => null,
            ], 404);
        }

        $isOwner = $viewer->id === $user->id;

        $hasApplicationToViewer = \App\Models\Application::where('worker_id', $user->id)
            ->whereHas('job', fn ($q) => $q->where('employer_id', $viewer->id))
            ->exists();

        if (!$isOwner && !$hasApplicationToViewer) {
            return response()->json([
                'success' => false,
                'message' => 'You can view this resume once this worker applies to one of your jobs',
                'data'    => null,
            ], 403);
        }

        if (!Storage::disk(config('filesystems.documents'))->exists($profile->resume_path)) {
            return response()->json([
                'success' => false,
                'message' => 'The file is missing',
                'data'    => null,
            ], 404);
        }

        // Downloads under the name the worker uploaded, not the random storage
        // name — an employer saving three CVs shouldn't end up with three
        // meaningless filenames.
        return Storage::disk(config('filesystems.documents'))->download(
            $profile->resume_path,
            $profile->resume_original_name ?: 'resume.pdf',
        );
    }

    /**
     * What the client is told about a resume.
     *
     * Deliberately never includes `resume_path`. The client has no use for the
     * storage path and shipping it invites someone to try building a URL from
     * it — the download endpoint is the only way in.
     */
    private function resumePayload(WorkerProfile $profile): array
    {
        return [
            'has_resume'  => $profile->hasResume(),
            'file_name'   => $profile->resume_original_name,
            'uploaded_at' => $profile->resume_uploaded_at?->toIso8601String(),
        ];
    }
}
