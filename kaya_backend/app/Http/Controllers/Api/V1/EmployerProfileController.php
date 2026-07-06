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
        $profile = $user->employerProfile()->firstOrCreate(['user_id' => $user->id]);
        return $this->ok(array_merge($profile->toArray(), [
            'name'  => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
        ]));
    }

    public function update(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'company_name' => ['nullable', 'string', 'max:255'],
            'description'  => ['nullable', 'string', 'max:2000'],
            'location'     => ['nullable', 'string', 'max:255'],
            'industry'     => ['nullable', 'string', 'max:255'],
            'website'      => ['nullable', 'url', 'max:255'],
            'employer_type'=> ['nullable', 'in:company,individual'],
        ]);

        $profile = EmployerProfile::updateOrCreate(['user_id' => $user->id], $data);
        return $this->ok($profile, 'Profile updated');
    }

    public function uploadLogo(Request $request)
    {
        $user = $request->user();

        $request->validate(['logo' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:5120']]);

        $profile = EmployerProfile::firstOrCreate(['user_id' => $user->id]);

        if ($profile->logo_path) Storage::disk('public')->delete($profile->logo_path);

        $path = $request->file('logo')->store('employer_logos', 'public');
        $profile->update(['logo_path' => $path]);

        return $this->ok(['logo_path' => $path], 'Logo uploaded');
    }
}
