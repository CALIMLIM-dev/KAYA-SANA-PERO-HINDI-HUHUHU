<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Verification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class VerificationController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /**
     * Submit a verification document.
     * For government_id: requires both id_photo and selfie_photo
     * For others: requires document only
     */
    public function store(Request $request)
    {
        $user = $request->user();
        
        // Check document type
        $type = $request->input('type');
        
        if ($type === 'government_id') {
            // Government ID requires ID photo, selfie photo, and ID type
            $request->validate([
                'type'          => ['required', 'string', 'in:government_id'],
                'id_type'       => ['required', 'string', 'max:100'],
                'id_photo'      => ['required', 'file', 'mimes:jpg,jpeg,png', 'max:5120'],
                'selfie_photo'  => ['required', 'file', 'mimes:jpg,jpeg,png', 'max:5120'],
            ]);
            
            /*
                Store first, then replace.

                The old record used to be deleted before the new files were
                written, so anything that went wrong while storing them - a
                disk the web server cannot write to, a full volume, a rejected
                upload - left the user with no verification at all. They had
                one a second earlier. Reported as a verification disappearing
                after submitting another one.

                Nothing is destroyed until the replacement exists.
            */
            $idPath = $request->file('id_photo')->store('verifications/ids', config('filesystems.documents'));
            $selfiePath = $request->file('selfie_photo')->store('verifications/selfies', config('filesystems.documents'));

            $verification = DB::transaction(function () use ($user, $type, $request, $idPath, $selfiePath) {
                Verification::where('user_id', $user->id)
                    ->where('document_type', $type)
                    ->delete();

                return Verification::create([
                    'user_id'             => $user->id,
                    'document_type'       => $type,
                    'id_type'             => $request->input('id_type'),
                    'document_front_url'  => $idPath,
                    'selfie_url'          => $selfiePath,
                    'status'              => 'pending',
                ]);
            });

            return $this->ok($verification, 'Government ID verification submitted. Under review within 1-2 business days.', 201);
            
        } else {
            // Other document types (business_reg, etc.)
            // Dashes off before the rule sees it: 123-456-789-000 is how it
            // is printed, and the regex below wants digits.
            if ($request->filled('tin')) {
                $request->merge(['tin' => preg_replace('/\D/', '', (string) $request->input('tin'))]);
            }

            $request->validate([
                'type'     => ['required', 'string', 'in:business_reg,business_permit,dti,sec'],
                'document' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
                // Nine digits for an old-format TIN, twelve with the branch
                // code. Dashes are stripped before this runs.
                'tin'      => ['nullable', 'string', 'regex:/^\d{9}(\d{3})?$/'],
            ], [
                'tin.regex' => 'A TIN is 9 or 12 digits, like 123-456-789-000.',
            ]);

            /*
                A company gives its TIN with its business document.

                Both a DTI certificate and a BIR 2303 carry it, so the admin
                checks the number against the paper in front of them rather
                than asking for one more upload. Required for a company and
                meaningless for an individual, who is refused it: a tax number
                on a personal account has nowhere to be checked.
            */
            $profile = $user->employerProfile;
            $isCompany = $profile?->employer_type?->requiresBusinessVerification() ?? false;
            $tin = \App\Models\EmployerProfile::normaliseTin($request->input('tin'));

            if ($isCompany && $tin === null) {
                return $this->fail('Please enter your business TIN.', 422);
            }

            if (! $isCompany && $tin !== null) {
                return $this->fail('Only a company account has a TIN to give.', 422);
            }

            // Stored before the old one is dropped - see the branch above.
            $path = $request->file('document')->store('verifications', config('filesystems.documents'));

            $verification = DB::transaction(function () use ($user, $type, $path, $profile, $tin) {
                Verification::where('user_id', $user->id)
                    ->where('document_type', $type)
                    ->delete();

                if ($tin !== null) {
                    $profile->forceFill(['tin' => $tin])->save();
                }

                return Verification::create([
                    'user_id'             => $user->id,
                    'document_type'       => $type,
                    'document_front_url'  => $path,
                    'status'              => 'pending',
                ]);
            });

            return $this->ok($verification, 'Verification submitted. Under review within 1-2 business days.', 201);
        }
    }

    /**
     * Get current user's verification statuses
     */
    public function index(Request $request)
    {
        $verifications = Verification::where('user_id', $request->user()->id)->get();
        return $this->ok($verifications);
    }
}
