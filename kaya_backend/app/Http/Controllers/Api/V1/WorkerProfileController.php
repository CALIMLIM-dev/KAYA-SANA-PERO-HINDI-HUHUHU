<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\WorkerSkill;
use App\Models\WorkerCertification;
use App\Models\WorkerLicense;
use App\Models\WorkerLicenseExamination;
use App\Models\WorkerExperience;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class WorkerProfileController extends Controller
{
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
        $skills = WorkerSkill::where('user_id', $request->user()->id)->get();
        
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
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $skill = WorkerSkill::create([
            'user_id' => $request->user()->id,
            'skill_name' => $request->skill_name,
            'proficiency_level' => $request->proficiency_level,
            'years_of_experience' => $request->years_of_experience,
        ]);
        
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
            'issue_date' => 'nullable|date',
            'expiry_date' => 'nullable|date',
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
            'issue_date' => 'nullable|date',
            'expiry_date' => 'nullable|date',
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
            'issue_date' => 'nullable|date',
            'expiry_date' => 'nullable|date',
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
            'issue_date' => 'nullable|date',
            'expiry_date' => 'nullable|date',
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
            'start_date' => 'required|date',
            'end_date' => 'nullable|date',
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
            'start_date' => 'required|date',
            'end_date' => 'nullable|date',
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
            'exam_date' => 'nullable|date',
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
            'exam_date' => 'nullable|date',
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
}
