<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Experience;
use App\Models\Certification;
use App\Models\Skill;
use App\Models\WorkerProfile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class WorkerProfileController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function show(Request $request)
    {
        $user    = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $profile = $user->workerProfile()->with(['skills', 'experiences', 'certifications'])->first();
        if (!$profile) return $this->fail('Worker profile not found', 404);

        return $this->ok(array_merge($profile->toArray(), [
            'name'                => $user->name,
            'email'               => $user->email,
            'phone'               => $user->phone,
            'profile_photo_path'  => $profile->profile_photo_path,
            'verification_status' => $profile->verification_status,
        ]));
    }

    public function update(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $data = $request->validate([
            'bio'                 => ['nullable', 'string', 'max:1000'],
            'availability_status' => ['required', 'in:available,busy,unavailable'],
        ]);

        $profile = WorkerProfile::firstOrCreate(['user_id' => $user->id]);
        $profile->update($data);

        return $this->ok($profile, 'Profile updated');
    }

    public function uploadPhoto(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $request->validate(['photo' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:5120']]);

        $profile = WorkerProfile::firstOrCreate(['user_id' => $user->id]);

        if ($profile->profile_photo_path) {
            Storage::disk('public')->delete($profile->profile_photo_path);
        }

        $path = $request->file('photo')->store('worker_photos', 'public');
        $profile->update(['profile_photo_path' => $path]);

        return $this->ok(['profile_photo_path' => $path], 'Photo uploaded');
    }

    public function attachSkill(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $request->validate(['skill_id' => ['required', 'exists:skills,id']]);

        $profile = $user->workerProfile;
        if (!$profile) return $this->fail('Worker profile not found', 404);

        if ($profile->skills()->where('skill_id', $request->skill_id)->exists()) {
            return $this->fail('Skill already attached', 409);
        }

        $profile->skills()->attach($request->skill_id);
        $skill = Skill::find($request->skill_id);

        return $this->ok($skill, 'Skill attached successfully', 201);
    }

    public function detachSkill(Request $request, Skill $skill)
    {
        $user    = $request->user();
        $profile = $user->workerProfile;
        if (!$profile) return $this->fail('Worker profile not found', 404);

        if (!$profile->skills()->where('skill_id', $skill->id)->exists()) {
            return $this->fail('Skill not attached to profile', 404);
        }

        $profile->skills()->detach($skill->id);
        return $this->ok(null, 'Skill detached successfully');
    }

    public function createExperience(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $data = $request->validate([
            'title'       => ['required', 'string', 'max:255'],
            'company'     => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'start_date'  => ['required', 'date'],
            'end_date'    => ['nullable', 'date', 'after:start_date'],
        ]);

        $profile = $user->workerProfile;
        if (!$profile) return $this->fail('Worker profile not found', 404);

        $exp = $profile->experiences()->create($data);
        return $this->ok($exp, 'Experience created', 201);
    }

    public function updateExperience(Request $request, Experience $experience)
    {
        $user    = $request->user();
        $profile = $user->workerProfile;

        if (!$profile || $experience->worker_profile_id !== $profile->id) {
            return $this->fail('Unauthorized to update this experience', 403);
        }

        $data = $request->validate([
            'title'       => ['required', 'string', 'max:255'],
            'company'     => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'start_date'  => ['required', 'date'],
            'end_date'    => ['nullable', 'date', 'after:start_date'],
        ]);

        $experience->update($data);
        return $this->ok($experience, 'Experience updated');
    }

    public function deleteExperience(Request $request, Experience $experience)
    {
        $profile = $request->user()->workerProfile;

        if (!$profile || $experience->worker_profile_id !== $profile->id) {
            return $this->fail('Unauthorized to delete this experience', 403);
        }

        $experience->delete();
        return $this->ok(null, 'Experience deleted successfully');
    }

    public function createCertification(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $data = $request->validate([
            'title'       => ['required', 'string', 'max:255'],
            'issuing_org' => ['required', 'string', 'max:255'],
            'issue_date'  => ['required', 'date'],
            'file'        => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:5120'],
        ]);

        $profile = $user->workerProfile;
        if (!$profile) return $this->fail('Worker profile not found', 404);

        if ($request->hasFile('file')) {
            $data['file_path'] = $request->file('file')->store('certifications', 'public');
        }
        unset($data['file']);

        $cert = $profile->certifications()->create($data);
        return $this->ok($cert, 'Certification created', 201);
    }

    public function deleteCertification(Request $request, Certification $cert)
    {
        $profile = $request->user()->workerProfile;

        if (!$profile || $cert->worker_profile_id !== $profile->id) {
            return $this->fail('Unauthorized to delete this certification', 403);
        }

        if ($cert->file_path) Storage::disk('public')->delete($cert->file_path);
        $cert->delete();

        return $this->ok(null, 'Certification deleted successfully');
    }
}
