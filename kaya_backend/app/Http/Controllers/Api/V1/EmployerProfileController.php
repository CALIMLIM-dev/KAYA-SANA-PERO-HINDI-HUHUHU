<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\EmployerProfile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class EmployerProfileController extends Controller
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
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        $profile = $user->employerProfile;
        if (!$profile) return $this->fail('Employer profile not found', 404);

        return $this->ok($profile);
    }

    public function update(Request $request)
    {
        $user = $request->user();
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        $data = $request->validate([
            'company_name' => ['nullable', 'string', 'max:255'],
            'description'  => ['nullable', 'string', 'max:2000'],
            'location'     => ['nullable', 'string', 'max:255'],
        ]);

        $profile = EmployerProfile::updateOrCreate(['user_id' => $user->id], $data);
        return $this->ok($profile, 'Profile updated');
    }

    public function uploadLogo(Request $request)
    {
        $user = $request->user();
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        $request->validate(['logo' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:5120']]);

        $profile = EmployerProfile::firstOrCreate(['user_id' => $user->id]);

        if ($profile->logo_path) Storage::disk('public')->delete($profile->logo_path);

        $path = $request->file('logo')->store('employer_logos', 'public');
        $profile->update(['logo_path' => $path]);

        return $this->ok(['logo_path' => $path], 'Logo uploaded');
    }
}
