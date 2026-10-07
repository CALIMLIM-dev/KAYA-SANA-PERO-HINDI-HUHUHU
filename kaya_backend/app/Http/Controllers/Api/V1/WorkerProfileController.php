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
    
    /*
        The worker profile of an account that already has an employer one.

        The seven-page setup flow exists to onboard somebody the app knows
        nothing about. A second profile is the opposite case: the name, the
        photo, the verified ID and the town are already on the account, and
        asking for all of them again is how one person ends up with two
        different pictures and two spellings of their own town.

        So the app asks for the one thing it cannot inherit - the trade and
        the skills - and this builds the rest from what is already there.

        Written in a transaction on purpose. Doing it the way the setup flow
        does, a PUT for the location and then one POST per skill, leaves a
        real profile behind the moment any of those calls fails: no category
        and no skills, which reads as a finished profile to the router and as
        an empty one to every employer looking at it. Either the whole profile
        exists or none of it does.
    */
    public function storeFromAccount(Request $request)
    {
        $user = $request->user();

        if (WorkerProfile::where('user_id', $user->id)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'You already have a worker profile.',
                'data'    => null,
            ], 422);
        }

        /*
            There is nothing to inherit without the other profile.

            This is the second-profile path and nothing else. An account with
            neither profile has no location, no confirmed name and no
            verification to carry over, so it belongs in the full setup flow -
            and letting it through here would create a profile with a null
            location, which is invisible to every distance calculation on the
            platform.
        */
        $employer = $user->employerProfile;

        if ($employer === null) {
            return response()->json([
                'success' => false,
                'message' => 'Set up your employer profile first, or use the full worker setup.',
                'data'    => null,
            ], 422);
        }

        if (blank($employer->location)) {
            return response()->json([
                'success' => false,
                'message' => 'Add a location to your employer profile first.',
                'data'    => null,
            ], 422);
        }

        $validator = Validator::make($request->all(), [
            // The trade. Required here, unlike everywhere else that writes a
            // worker profile, because a profile with no category is one
            // nobody can be found by - browse() excludes it outright.
            'category_id'          => 'required|integer|exists:categories,id',
            'skills'               => 'required|array|min:1|max:30',
            'skills.*.skill_name'  => 'required|string|max:255',
            'skills.*.skill_id'    => 'nullable|integer|exists:skills,id',
            'skills.*.category_id' => 'nullable|integer|exists:categories,id',
        ], [
            'category_id.required' => 'Choose the kind of work you do.',
            'skills.required'      => 'Add at least one skill.',
            'skills.min'           => 'Add at least one skill.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data'    => null,
            ], 422);
        }

        $data = $validator->validated();

        $profile = DB::transaction(function () use ($user, $employer, $data) {
            $profile = WorkerProfile::create([
                'user_id'     => $user->id,
                'category_id' => $data['category_id'],
                // Inherited whole, coordinates included. A label without an
                // id has no coordinates, and a worker without coordinates is
                // absent from every proximity search and every distance
                // figure on a job card.
                'location'            => $employer->location,
                'location_id'         => $employer->location_id,
                'latitude'            => $employer->latitude,
                'longitude'           => $employer->longitude,
                'availability_status' => 'available',
                'verification_status' => 'unverified',
            ]);

            /*
                Duplicates are dropped rather than refused.

                addSkill 422s on one, which is right when somebody is adding a
                skill to a profile in front of them. Here the list arrives in
                one go from a picker, and losing the whole profile over a
                repeated name is a failure the user cannot act on.
            */
            $seen = [];

            foreach ($data['skills'] as $skill) {
                $key = mb_strtolower(trim($skill['skill_name']));

                if ($key === '' || isset($seen[$key])) {
                    continue;
                }

                $seen[$key] = true;

                WorkerSkill::create([
                    'user_id'     => $user->id,
                    'skill_name'  => trim($skill['skill_name']),
                    'skill_id'    => $skill['skill_id'] ?? null,
                    'category_id' => $skill['category_id'] ?? $data['category_id'],
                    // Not stated, rather than invented. See addSkill.
                    'proficiency_level'   => null,
                    'years_of_experience' => null,
                ]);
            }

            return $profile;
        });

        /*
            The account's own city follows, the same as any other save.

            The employer profile is the source here so nothing actually moves,
            but going through the one service keeps this path from becoming
            the exception that drifts.
        */
        app(\App\Services\SharedIdentity::class)->spreadLocation(
            $user,
            $profile->location,
            $profile->location_id,
            $profile->latitude === null ? null : (float) $profile->latitude,
            $profile->longitude === null ? null : (float) $profile->longitude,
        );

        // Open jobs this worker now fits, the moment the profile can be
        // matched at all. See NotificationService::workerMatched.
        app(\App\Services\NotificationService::class)->workerMatched($profile->fresh());

        return response()->json([
            'success' => true,
            'data'    => [
                'location'       => $profile->location,
                'category_id'    => $profile->category_id,
                'setup_complete' => $profile->fresh()->isSetupCompleted(),
            ],
            'message' => 'Worker profile created',
        ], 201);
    }

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
            'first_name'  => 'nullable|string|max:100',
            'middle_name' => 'nullable|string|max:100',
            'last_name'   => 'nullable|string|max:100',
            'suffix'      => 'nullable|string|max:20',
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
            // A few lines about the work, shown on the public profile.
            'bio'                => 'nullable|string|max:500',
        ]);
        
        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }
        
        $user = $request->user();
        
        /*
            The parts first, then `name` only as a fallback.

            An older build still sends a single `name`, and a current one
            sends the four fields. Applying the parts and letting
            User::booted recompose the display name means the two can never
            disagree - and the plain `name` write is skipped when parts are
            present, or it would be overwritten a moment later anyway.
        */
        /*
            A verified account cannot rename itself here either.

            AuthController@updateMe refuses this, for a reason written out in
            full there: verification means an administrator matched a name to
            a government ID, so letting the name change afterwards leaves the
            badge vouching for somebody nobody checked.

            But this is a second endpoint that writes the same four columns,
            and it had no such check - so the whole lock came off simply by
            saving a worker profile. Anyone verified could set up the other
            side of their account under a different name and keep the tick.

            Compared on the composed result rather than field by field, so
            fixing a spelling that produces the same display name is not
            treated as a rename.
        */
        $sentParts = $request->hasAny(['first_name', 'middle_name', 'last_name', 'suffix']);

        if ($user->is_verified && ($sentParts || $request->filled('name'))) {
            $proposed = $sentParts
                ? \App\Models\User::composeName(
                    $request->input('first_name', $user->first_name),
                    $request->input('middle_name', $user->middle_name),
                    $request->input('last_name', $user->last_name),
                    $request->input('suffix', $user->suffix),
                )
                : $request->input('name');

            if (trim((string) $proposed) !== trim((string) $user->name)) {
                return response()->json([
                    'success' => false,
                    'data' => null,
                    'message' => 'Your name is locked because your ID has been '
                        . 'verified. Contact support if you need to change it.',
                ], 422);
            }
        }

        foreach (['first_name', 'middle_name', 'last_name', 'suffix'] as $part) {
            if ($request->has($part)) {
                $user->{$part} = $request->input($part) ?: null;
            }
        }

        if (!$sentParts && $request->filled('name')) {
            $user->name = $request->name;
        }
        
        if ($request->filled('city')) {
            $user->city = $request->city;
        }
        
        if ($request->filled('phone')) {
            $user->phone = $request->phone;
        }
        
        $user->save();

        /*
            A company account cannot also be a worker.

            The rule everywhere else in this app is that roles come from
            profile existence and one account may hold both. This is the
            single exception, and it is deliberate: a registered business
            hiring through KAYA is not also a tradesperson looking for
            work, and a verified-business badge on an account that is
            sometimes a company and sometimes a person vouches for nothing.

            Going forward only. Accounts that already hold both are left
            alone rather than migrated - this is a live system in testing,
            and taking a profile away from somebody mid-demo is a worse
            outcome than a few grandfathered accounts. kaya:audit-company-
            hybrids lists them without changing anything.
        */
        // Refused by the not.company middleware on this route, which
        // covers every endpoint that can create the profile rather
        // than the two that remembered to check.

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

        /*
            A pin belongs to the city it was dropped in.

            A worker who moves their profile to another town without dropping
            a new pin would otherwise keep coordinates in the old one, and be
            listed as "2 km away" from jobs two provinces off. With no pin
            the distance code falls back to the town centre, which is right.
        */
        $movedCity = $request->filled('location_id')
            && (int) $request->input('location_id') !== (int) $profile->location_id;

        if ($movedCity && ! $request->filled('latitude')) {
            $profile->latitude = null;
            $profile->longitude = null;
            $profileDirty = true;
        }

        foreach (['location_id', 'latitude', 'longitude', 'rate_min', 'rate_max', 'rate_unit'] as $field) {
            if ($request->filled($field)) {
                $profile->{$field} = $request->input($field);
                $profileDirty = true;
            }
        }

        // has(), not filled(): sending an empty bio clears it.
        if ($request->has('bio')) {
            $profile->bio = trim((string) $request->input('bio')) ?: null;
            $profileDirty = true;
        }

        if ($profileDirty) {
            $profile->save();

            /*
                One person lives in one place.

                A hybrid account holding two profiles used to keep two
                locations, so moving town on one side left the other
                advertising the old one. See SharedIdentity.
            */
            app(\App\Services\SharedIdentity::class)->spreadLocation(
                $user,
                $profile->location,
                $profile->location_id,
                $profile->latitude === null ? null : (float) $profile->latitude,
                $profile->longitude === null ? null : (float) $profile->longitude,
            );
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

        /*
            A company account cannot also be a worker.

            The rule everywhere else in this app is that roles come from
            profile existence and one account may hold both. This is the
            single exception, and it is deliberate: a registered business
            hiring through KAYA is not also a tradesperson looking for
            work, and a verified-business badge on an account that is
            sometimes a company and sometimes a person vouches for nothing.

            Going forward only. Accounts that already hold both are left
            alone rather than migrated - this is a live system in testing,
            and taking a profile away from somebody mid-demo is a worse
            outcome than a few grandfathered accounts. kaya:audit-company-
            hybrids lists them without changing anything.
        */
        // Refused by the not.company middleware on this route, which
        // covers every endpoint that can create the profile rather
        // than the two that remembered to check.

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

        // A new skill can make this worker the fit for a job already open.
        app(\App\Services\NotificationService::class)->workerMatched($profile->fresh());

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
            'sort'        => ['nullable', 'in:best,rating,jobs,nearest,newest'],
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
            // The place and everything in it - a city includes its barangays,
            // which is where workers actually are.
            $place = \App\Models\Location::find($data['location_id']);

            $query->whereIn(
                'location_id',
                $place ? $place->subtreeIds() : [$data['location_id']]
            );
        }

        if (!empty($data['skill_id'])) {
            $query->whereHas('skills', fn ($q) => $q->where('skill_id', $data['skill_id']));
        }

        if (!empty($data['q'])) {
            // Word by word and forgiving of a misspelling, the same way the
            // job feed searches. See TextSearch.
            app(\App\Services\TextSearch::class)->workers($query, (string) $data['q']);
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

        /*
            A radius needs a centre.

            The filter above reads "drop anyone whose distance is unknown",
            which is right when the viewer has a position and a particular
            worker cannot be placed. It is catastrophic when the viewer has no
            position: workerDistance() then returns null for everybody, every
            row fails the test, and the endpoint answers with an empty list.

            The app always sends radius_km, so any employer whose profile
            carries no coordinates - one who has not finished setting up, or
            picked a place with no centroid - saw "People who can help" empty
            forever, with nothing to say why. Widening the search could not
            help either, because there was no point to widen around.

            So the radius only applies when there is somewhere to measure
            from. Without one the list is unfiltered and unsorted, which is
            honest: these are workers, just not ordered by a distance nobody
            can compute.
        */
        $viewerHasPosition = $viewerLat !== null && $viewerLng !== null;

        if (!empty($data['radius_km']) && $viewerHasPosition) {
            $withDistance = $withDistance->filter(
                fn (WorkerProfile $p) => $p->computed_distance_km !== null
                    && $p->computed_distance_km <= $data['radius_km']
            );
        }

        /*
            The order the directory comes back in.

            It used to be nearest-first and nothing else, which answers "who is
            closest" - not "who should I hire", which is the question an
            employer opening this screen is actually asking. Distance is one
            input now rather than the whole answer.

            Every input is already on the row or already counted elsewhere, and
            each one is worth points a person can be told about:

                paid boost      lifts a worker above the list for three days
                rating          up to 5, weighted by how many reviews back it
                jobs finished   up to 3, flattening out at ten
                verified ID     2
                nearby          2 within 10km, 1 within 25km

            Weighted rather than raw so one five-star review does not outrank
            forty jobs at 4.6 - the same reason the Highly Rated badge needs
            five reviews before it appears.
        */
        $ids = $withDistance->pluck('user_id')->all();

        // Two queries for the whole page rather than two per worker.
        $boosted = $ids === [] ? collect() : \App\Models\Boost::query()
            ->active()
            ->where('boostable_type', \App\Models\Boost::TYPE_WORKER)
            ->whereIn('boostable_id', $ids)
            ->pluck('boostable_id')
            ->flip();

        // worker_id, not user_id: an application belongs to the worker
        // under that name, and asking for the wrong column here took the
        // whole directory down with a 500.
        $finished = $ids === [] ? collect() : \App\Models\Application::query()
            ->select('worker_id', DB::raw('count(*) as total'))
            ->where('status', 'completed')
            ->whereIn('worker_id', $ids)
            ->groupBy('worker_id')
            ->pluck('total', 'worker_id');

        $withDistance = $withDistance->map(function (WorkerProfile $p) use ($boosted, $finished) {
            $reviews = (int) $p->rating_count;
            $rating  = (float) $p->rating_avg;
            $done    = (int) ($finished[$p->user_id] ?? 0);
            $km      = $p->computed_distance_km;

            $score = ($rating / 5) * (min($reviews, 5) / 5) * 5
                + (min($done, 10) / 10) * 3
                + ($p->user?->is_verified ? 2 : 0)
                + ($km === null ? 0 : ($km <= 10 ? 2 : ($km <= 25 ? 1 : 0)));

            $p->setAttribute('is_boosted', $boosted->has($p->user_id));
            $p->setAttribute('jobs_completed', $done);
            $p->setAttribute('rank_score', round($score, 2));

            return $p;
        });

        $sort = $data['sort'] ?? 'best';

        /*
            A paid boost leads whichever order the viewer chose.

            It used to lead only this list's default. Pick Highest rated, Most
            jobs, Nearest or Newest and the boost was not in the key at all -
            so a boosted profile fell exactly where its rating or its distance
            put it, and a new worker who had just paid for placement landed at
            the bottom of the page they had paid to be at the top of.

            That is the same failure the urgent flag had: money taken, nothing
            delivered. The jobs feed already guards its own distance sort this
            way; the directory did not.

            The boost is the first element of every key, so it sits above the
            ranking rather than inside it - three days of placement cannot be
            undone by one bad week, and within the boosted group the chosen
            order still applies.

            Ascending for 'nearest', so 0 comes first there and 1 comes first
            in the descending sorts.
        */
        $withDistance = match ($sort) {
            'rating'  => $withDistance->sortByDesc(
                fn (WorkerProfile $p) => [$p->is_boosted ? 1 : 0, $p->rating_avg, $p->rating_count]
            ),
            'jobs'    => $withDistance->sortByDesc(
                fn (WorkerProfile $p) => [$p->is_boosted ? 1 : 0, $p->jobs_completed]
            ),
            'nearest' => $withDistance->sortBy(
                fn (WorkerProfile $p) => [
                    $p->is_boosted ? 0 : 1,
                    $p->computed_distance_km ?? PHP_FLOAT_MAX,
                ]
            ),
            'newest'  => $withDistance->sortByDesc(
                fn (WorkerProfile $p) => [$p->is_boosted ? 1 : 0, $p->created_at]
            ),
            default   => $withDistance->sortByDesc(
                fn (WorkerProfile $p) => [$p->is_boosted ? 1 : 0, $p->rank_score]
            ),
        };

        $profiles = $withDistance->values();

        $perPage = $data['per_page'] ?? 20;
        $page = (int) $request->input('page', 1);
        $paged = $profiles->forPage($page, $perPage)->values();

        /*
            Who is on a job right now, for the whole page at once.

            One query rather than one per card. See availabilityOf for
            why this is asked of the hires instead of read off the
            profile column.
        */
        $onAJob = $this->workersOnAJob($paged->pluck('user_id')->all());

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
                    // What the ranking used, so a card can say "Boosted"
                    // and show the work behind the position it is in.
                    'is_boosted'     => (bool) $p->is_boosted,
                    'jobs_completed' => (int) $p->jobs_completed,
                    'rate_min'           => $p->rate_min,
                    'rate_max'           => $p->rate_max,
                    'rate_unit'          => $p->rate_unit,
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
                    // Derived, not read. See availabilityOf.
                    'availability_status' => in_array($p->user_id, $onAJob, true)
                        ? 'busy'
                        : 'available',
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
    // Both live in App\Support\DistanceBand now, shared with the job feed.
    private function bucketDistance(?float $km): ?float
    {
        return \App\Support\DistanceBand::bucket($km);
    }

    private function distanceLabel(?float $km): ?string
    {
        return \App\Support\DistanceBand::label($km);
    }

    /*
        Whether this worker is on a job, in the only terms the platform
        can actually answer.

        worker_profiles.availability_status is written in four places and
        all four write 'available'. Nothing ever wrote anything else, so
        the card said "Available now" for every worker forever - for
        somebody in the middle of a hire, and for an account that had not
        been opened since it was made. An employer reading that badge was
        being told nothing while believing they had been told something.

        An accepted application that has not completed is a hire in
        progress. That is a fact with a row behind it, and it is the
        question an employer is really asking.
    */
    private function availabilityOf(int $userId): string
    {
        return $this->workersOnAJob([$userId]) === []
            ? 'available'
            : 'busy';
    }

    /**
     * Which of these workers hold an unfinished accepted hire.
     *
     * @param  array<int>  $userIds
     * @return array<int>
     */
    private function workersOnAJob(array $userIds): array
    {
        if ($userIds === []) {
            return [];
        }

        return \App\Models\Application::whereIn('worker_id', $userIds)
            ->where('status', 'accepted')
            ->distinct()
            ->pluck('worker_id')
            ->map(fn ($id) => (int) $id)
            ->all();
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
            /*
                The job each review was for.

                A rehired worker collects several reviews from the same
                employer, correctly - but the list showed a name, a score and
                a comment with nothing to say which job any of it was about,
                so four reviews from one employer read as four opinions of the
                same work rather than of four different jobs.
            */
            ->with(['reviewer:id,name', 'job:id,title,category_id', 'job.category:id,name'])
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
            employer weighing a hire, not to every account in the app. So the
            rule is the owner, or an employer this worker has actually
            applied to.

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
                // Derived, not read. See availabilityOf.
                'availability_status' => $this->availabilityOf($profile->user_id),
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

                /*
                    What their finished work says, not just what people
                    scored it.

                    A rating is an opinion; a completion record is a fact,
                    and until now neither profile carried one. success_rate
                    is null rather than 0 for somebody with nothing finished
                    yet — see WorkRecord.
                */
                ...app(\App\Services\WorkRecord::class)->forWorker($user),

                // What they charge. rate_label is the phrasing every surface
                // shows; the raw numbers are for the edit form and filtering.
                'rate_min'            => $profile->rate_min,
                'rate_max'            => $profile->rate_max,
                'rate_unit'           => $profile->rate_unit,
                'rate_label'          => $profile->rateLabel(),

                // Skills carry proficiency and years — an employer choosing
                // between two masons needs those, not just the label.
                'skills'              => $profile->skills->map(fn ($s) => [
                    'name'                => $s->skill_name,
                    'proficiency_level'   => $s->proficiency_level,
                    'years_of_experience' => $s->years_of_experience,
                ])->values(),

                /*
                    Computed, never stored, and overlapping jobs count once.

                    Summing the rows would tell an employer four years for a
                    mason who spent 2020-2022 on two sites at once, and the
                    dates it contradicts are listed directly underneath.
                */
                // Read from the record on every request rather than stored -
                // see the note in BadgeService for why there is no table.
                'badges'              => app(\App\Services\BadgeService::class)
                    ->forWorker($user),

                'years_experience'    => app(\App\Services\ExperienceTotal::class)
                    ->years($profile->experiences),
                'experience_label'    => app(\App\Services\ExperienceTotal::class)
                    ->label($profile->experiences),

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
                    // Which job this was for, so several reviews from the
                    // same employer read as several jobs.
                    'job_title' => $r->job?->title,
                    'job_category' => $r->job?->category?->name,
                ])->values(),
            ],
            'message' => 'Success',
        ]);
    }
}
