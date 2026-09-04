<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Mail;
use App\Mail\PasswordResetMail;
use App\Services\GoogleTokenVerifier;

class AuthController extends Controller
{
    private function ok($data, string $message = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $message], $status);
    }

    private function fail(string $message, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $message], $status);
    }

    public function register(Request $request)
    {
        $request->validate([
            'name'     => ['nullable', 'string', 'max:255'],
            /*
                The name, as four fields.

                `name` stays accepted so an older build keeps working, but
                when the parts arrive they win: User::booted recomputes the
                display name from them on save. first and last are what a
                person is addressed by; middle (the mother's maiden surname
                here) and suffix are genuinely optional and must never be
                required, or anyone without one cannot finish signing up.
            */
            'first_name'  => ['nullable', 'string', 'max:100'],
            'middle_name' => ['nullable', 'string', 'max:100'],
            'last_name'   => ['nullable', 'string', 'max:100'],
            'suffix'      => ['nullable', 'string', 'max:20'],
            'email'    => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'phone'    => ['nullable', 'string', 'max:20'],
            'city'     => ['nullable', 'string', 'max:255'],
            'terms_accepted' => ['required', 'boolean', 'accepted'],
        ]);

        $input = $request->input('email');
        $isPhone = str_starts_with($input, '+') || ctype_digit(ltrim($input, '+'));

        if ($isPhone) {
            // Check phone not already taken
            if (User::where('phone', $input)->exists()) {
                return $this->fail('This phone number is already registered.', 422);
            }
            $userData = [
                'name'     => $request->input('name') ?: null,
                // The parts are the source of truth; User::booted rebuilds
                // `name` from them, so a caller sending both cannot disagree.
                'first_name'  => $request->input('first_name') ?: null,
                'middle_name' => $request->input('middle_name') ?: null,
                'last_name'   => $request->input('last_name') ?: null,
                'suffix'      => $request->input('suffix') ?: null,
                'email'    => null,
                'phone'    => $input,
                'password' => $request->input('password'),
                'terms_accepted' => true,
                'terms_accepted_at' => now(),
            ];
        } else {
            // Validate as email
            if (!filter_var($input, FILTER_VALIDATE_EMAIL)) {
                return $this->fail('Please enter a valid email address.', 422);
            }
            if (User::where('email', $input)->exists()) {
                return $this->fail('This email is already registered.', 422);
            }
            $userData = [
                'name'     => $request->input('name') ?: null,
                // The parts are the source of truth; User::booted rebuilds
                // `name` from them, so a caller sending both cannot disagree.
                'first_name'  => $request->input('first_name') ?: null,
                'middle_name' => $request->input('middle_name') ?: null,
                'last_name'   => $request->input('last_name') ?: null,
                'suffix'      => $request->input('suffix') ?: null,
                'email'    => $input,
                'password' => $request->input('password'),
                'terms_accepted' => true,
                'terms_accepted_at' => now(),
            ];
        }

        $user  = User::create($userData);
        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['user' => $this->ownAccount($user), 'token' => $token], 'Registration successful', 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email'    => ['required', 'string'],
            'password' => ['required'],
        ]);

        $input = $request->input('email'); // could be email or phone (+63XXXXXXXXXX)

        // Detect if it's a phone number (starts with + or is all digits)
        if (str_starts_with($input, '+') || ctype_digit($input)) {
            $user = User::where('phone', $input)->first();
        } else {
            $user = User::where('email', $input)->first();
        }

        if (!$user || !Hash::check($request->password, $user->password)) {
            return $this->fail('Incorrect email or password', 401);
        }

        if ($user->is_suspended) {
            return response()->json([
                'success' => false,
                'data' => [
                    'is_suspended' => true,
                    'suspended_reason' => $user->suspended_reason,
                ],
                'message' => 'Account suspended',
            ], 403);
        }

        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['user' => $this->ownAccount($user), 'token' => $token], 'Login successful');
    }

    /**
     * Sign out. Deliberately tolerant of a missing or already-revoked token:
     * the route runs without auth so that a client whose token was destroyed
     * underneath it (suspension does exactly that) can still complete its
     * sign-out instead of retrying a 401 forever.
     */
    public function logout(Request $request)
    {
        $user = $request->user() ?? Auth::guard('sanctum')->user();
        $user?->currentAccessToken()?->delete();

        return $this->ok(null, 'Logged out');
    }

    /**
     * The account holder's own record, with their contact details restored.
     *
     * `User::$hidden` withholds email, phone and google_id so they cannot ride
     * along on an eager-loaded relation and leak to strangers. That default is
     * right everywhere except here: someone is entitled to see their own email
     * address, and the app reads it after signing in.
     *
     * Moderation columns stay hidden even from the owner — a suspension note is
     * written for administrators, not for the person it describes.
     */
    private function ownAccount(User $user): User
    {
        return $user->makeVisible(['email', 'phone', 'google_id']);
    }

    public function me(Request $request)
    {
        $user = $request->user();
        
        // Check if user is suspended
        if ($user->is_suspended) {
            return response()->json([
                'success' => false,
                'data' => [
                    'is_suspended' => true,
                    'suspended_reason' => $user->suspended_reason,
                ],
                'message' => 'Account suspended',
            ], 403);
        }

        // Eager load profiles
        $employerProfile = $user->employerProfile;
        $workerProfile = $user->workerProfile;
        
        // For worker profile, need to load skills relationship to check completion
        if ($workerProfile) {
            $workerProfile->load('skills');
        }
        
        return $this->ok([
            'id' => $user->id,
            'name' => $user->name,

            /*
                The name in parts, and whether it can still be changed.

                This endpoint sent the composed name only. Both setup
                flows read the parts to prefill their fields and to
                decide whether to lock them, so they read null every
                time: the second profile asked for a name the account
                had already given, and accepted a different one.

                name_locked is answered here rather than worked out in
                the app, because the app cannot see the whole rule -
                a verified name is fixed because an administrator
                matched it to an ID, and an unverified one is fixed
                during setup because the account already has it and two
                profiles cannot disagree about who they belong to. It
                is still changeable from the profile screen while the
                account is unverified, which is the one place that
                edits it.
            */
            'first_name'  => $user->nameParts()['first_name'],
            'middle_name' => $user->nameParts()['middle_name'],
            'last_name'   => $user->nameParts()['last_name'],
            'suffix'      => $user->nameParts()['suffix'],
            'name_locked' => $user->is_verified || filled($user->name),

            'email' => $user->email,
            'phone' => $user->phone,
            'city' => $user->city,

            /*
                The location this account already told us, with its id.

                Setting up the second profile asked for a location the account
                had already given on the first, and the picker needs the PSGC
                row id - not just the label - or the profile saves with no
                coordinates and the account is invisible to every distance
                calculation. `city` alone could not prefill it safely, so it
                was simply asked again.

                Whichever profile has one; they are the same person standing
                in the same place.
            */
            'known_location' => (function () use ($workerProfile, $employerProfile) {
                foreach ([$workerProfile, $employerProfile] as $p) {
                    if ($p?->location_id === null) {
                        continue;
                    }

                    /*
                        The same place at both grains.

                        A worker picks a barangay and an employer picks a
                        city, so handing the employer setup the worker's
                        stored location prefilled it with a barangay - the
                        exact value the employer side refuses to offer in
                        its own picker. `city` is that location resolved
                        upwards: the row itself when it is already a city or
                        municipality, its parent when it is a barangay.
                    */
                    $row = \App\Models\Location::find($p->location_id);

                    $city = $row?->type === \App\Models\Location::TYPE_BARANGAY
                        ? $row->parent
                        : $row;

                    return [
                        'label'       => $p->location,
                        'location_id' => $p->location_id,
                        'latitude'    => $p->latitude,
                        'longitude'   => $p->longitude,
                        'city' => $city === null ? null : [
                            'label'       => $city->display_name ?? $city->name,
                            'location_id' => $city->id,
                            'latitude'    => $city->latitude === null ? null : (float) $city->latitude,
                            'longitude'   => $city->longitude === null ? null : (float) $city->longitude,
                        ],
                    ];
                }

                return null;
            })(),
            // Resolved, not the raw column: an account that uploaded a
            // picture during setup stored it on the worker or employer
            // profile, and users.avatar is only ever the Google photo - so
            // this screen showed a letter to people who had a picture.
            'avatar' => $user->resolvedAvatarUrl(),
            'is_verified' => $user->is_verified,
            /*
                Contact verification, which the app could not see.

                Unlike a government ID these are not rows in `verifications` -
                ContactVerificationController stamps a column on the user - so
                statusFor('phone') always answered "unverified" and every card
                that tried to show it was hard-coded to false. Sent here as
                plain booleans so the profile can draw the real state.
            */
            'email_verified' => $user->email_verified_at !== null,
            'phone_verified' => $user->phone_verified_at !== null,
            'user_type' => $user->user_type,
            
            // Employer profile flags
            'employer_profile_exists' => $employerProfile !== null,
            'employer_type' => $employerProfile?->employer_type?->value,
            'employer_setup_completed' => $employerProfile?->isSetupCompleted() ?? false,

            // Worker profile flags
            'worker_profile_exists' => $workerProfile !== null,
            'worker_setup_completed' => $workerProfile?->isSetupCompleted() ?? false,

            // How complete the profile employers actually read is, plus the
            // single next thing worth doing. Served from /me so every screen
            // shows the same number — see WorkerProfile::completeness().
            'worker_profile_completeness' => $workerProfile?->completeness(),

            /*
                Whether a resume is on file.

                The upload and delete endpoints returned this and nothing else
                did, so the app had no way to know a resume existed and no way
                to show one - the whole feature was reachable only by an
                account that had just uploaded, and then only until the screen
                rebuilt.

                The path is deliberately absent. A resume carries a phone
                number, a home address and an employment history, and it is
                served through a gated download rather than by URL.
            */
            'resume' => $workerProfile === null ? null : [
                'has_resume'  => $workerProfile->hasResume(),
                'file_name'   => $workerProfile->resume_original_name,
                'uploaded_at' => $workerProfile->resume_uploaded_at?->toIso8601String(),
            ],
        ]);
    }
    
    /**
     * Check suspension status (called periodically by app)
     */
    public function checkStatus(Request $request)
    {
        $user = $request->user();
        
        return $this->ok([
            'is_suspended' => $user->is_suspended,
            'suspended_reason' => $user->suspended_reason,
        ]);
    }

    /**
     * Update current user's basic info (name, phone)
     */
    /**
     * Changes the account password.
     *
     * The settings screen had this form already, with three fields and an
     * "Update Password" button that closed the sheet and announced success
     * without sending anything — so nobody's password ever changed.
     *
     * Requires the current password. Without it, anyone holding a phone that
     * is already signed in could lock the owner out of their own account.
     */
    public function changePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password'         => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            return $this->fail('Your current password is incorrect.', 422);
        }

        if (Hash::check($data['password'], $user->password)) {
            return $this->fail('Your new password must be different from the current one.', 422);
        }

        $user->forceFill(['password' => Hash::make($data['password'])])->save();

        /*
            Every other session is signed out, and this one is re-issued.

            A password change usually means "someone else may have my
            password". Leaving their tokens alive would make the change
            pointless. The new token is returned so the app can carry on
            without bouncing the user to the login screen.
        */
        $user->tokens()->delete();
        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['token' => $token], 'Password updated. Other devices have been signed out.');
    }

    public function notificationPreferences(Request $request)
    {
        return $this->ok(['preferences' => $request->user()->notificationPreferences()]);
    }

    /**
     * Saves the settings switches.
     *
     * They were widget state before this existed: flipping one changed
     * nothing, and the value was gone as soon as the screen closed.
     */
    public function updateNotificationPreferences(Request $request)
    {
        /*
            A partial update, merged over what is stored.

            These used to be `required`, which meant the request had to carry
            every category. That is fine until a category is added: an app
            build that predates it sends the older, shorter set and every save
            starts failing with a 422 that says nothing useful to the person
            toggling a switch. Since installed apps are not upgraded in step
            with the server, "send them all" is not a contract this endpoint can
            hold.

            `sometimes` accepts whichever subset arrives, and merging keeps
            categories the client did not mention rather than dropping them to
            false — a switch nobody touched should not silently turn off.
        */
        $rules = [];
        foreach (User::NOTIFICATION_CATEGORIES as $category) {
            $rules[$category] = ['sometimes', 'boolean'];
        }

        $data = $request->validate($rules);

        $user = $request->user();
        $merged = array_merge($user->notificationPreferences(), $data);

        $user->forceFill(['notification_preferences' => $merged])->save();

        return $this->ok(
            ['preferences' => $request->user()->fresh()->notificationPreferences()],
            'Notification settings saved.'
        );
    }

    public function updateMe(Request $request)
    {
        $data = $request->validate([
            'name'  => ['nullable', 'string', 'max:255'],
            'first_name'  => ['nullable', 'string', 'max:100'],
            'middle_name' => ['nullable', 'string', 'max:100'],
            'last_name'   => ['nullable', 'string', 'max:100'],
            'suffix'      => ['nullable', 'string', 'max:20'],
            'phone' => ['nullable', 'string', 'max:20'],
        ]);

        $user = $request->user();

        if (!empty($data['name']) && $data['name'] !== $user->name) {
            // A verified account cannot rename itself.
            //
            // One name identifies the whole account — it is shown on the worker
            // profile, on jobs posted as an employer, in chat and against every
            // review. Verification means an administrator matched that name to
            // a government ID.
            //
            // Without this check, the employer setup flow could rewrite it
            // freely: a worker could verify as one person, collect reviews and
            // a verified badge, then rename the account to somebody else and
            // keep both. The badge would still be displayed, now vouching for a
            // name nobody ever checked.
            //
            // Changing a verified name has to go back through verification, so
            // it is refused here rather than silently un-verifying the account.
            if ($user->is_verified) {
                return $this->fail(
                    'Your name is locked because your ID has been verified. '
                    . 'Contact support if you need to change it.',
                    422
                );
            }

            $user->name = $data['name'];
        }

        /*
            The parts run through the same verification lock.

            The check above guards `name`, and `name` is now derived from
            these — so writing the parts without this would walk straight
            around it: a verified account could rename itself by sending
            first_name instead of name, and keep the badge that vouched
            for the old one. The composed result is compared rather than
            each field, so correcting a spelling to the same display name
            is not treated as a rename.
        */
        $partKeys = ['first_name', 'middle_name', 'last_name', 'suffix'];

        if ($request->hasAny($partKeys)) {
            $proposed = \App\Models\User::composeName(
                $data['first_name']  ?? $user->first_name,
                $data['middle_name'] ?? $user->middle_name,
                $data['last_name']   ?? $user->last_name,
                $data['suffix']      ?? $user->suffix,
            );

            if ($user->is_verified && $proposed !== $user->name) {
                return $this->fail(
                    'Your name is locked because your ID has been verified. '
                    . 'Contact support if you need to change it.',
                    422
                );
            }

            foreach ($partKeys as $key) {
                if (array_key_exists($key, $data)) {
                    $user->{$key} = $data[$key] ?: null;
                }
            }
        }

        if (array_key_exists('phone', $data) && !empty($data['phone'])) {
            $user->phone = $data['phone'];
        }

        $user->save();

        return $this->ok($this->ownAccount($user), 'Profile updated');
    }

    /**
     * Google Sign-In — Returns Google user data for app to handle password setup
     */
    public function googleLogin(Request $request)
    {
        $request->validate([
            'id_token'  => ['required', 'string'],
            'password'  => ['nullable', 'string', 'min:8'],
            'is_signup' => ['nullable', 'boolean'],
            /*
                Consent, same as the email form asks for.

                Email registration requires terms_accepted to be true; Google
                signup validated none of it, so an account made with Google was
                created having agreed to nothing — no record of consent at all,
                which the Data Privacy Act does not allow. Required only when
                this call actually creates an account, so an existing user
                signing back in is not asked to agree again.
            */
            /*
                Terms required on the account-creating call only.

                Google's native Android sign-in does not reliably show its own
                consent screen for basic scopes, so KAYA gates the terms on its
                password screen instead. That screen sends terms_accepted with
                the password, which is the call that actually creates the
                account - the probe (is_signup, no password) is excluded, or it
                would fail on terms before it could return "password required"
                and the app would never reach the terms screen.
            */
            'terms_accepted' => [
                Rule::excludeIf(! ($request->boolean('is_signup') && $request->filled('password'))),
                'required',
                'accepted',
            ],
        ]);

        /*
            Identity comes from the token, never from the request.

            This endpoint used to accept `google_id` and `email` as plain fields
            and log in whoever owned that address. Anyone who knew a user's email
            could post it with any made-up google_id and receive a working API
            token for that account — no password, no contact with Google.

            Everything below now uses claims Google signed. The client can still
            send whatever it likes; none of it is read.
        */
        try {
            $claims = app(GoogleTokenVerifier::class)->verify($request->string('id_token'));
        } catch (\RuntimeException $e) {
            return $this->fail($e->getMessage(), 401);
        }

        $googleId = $claims['sub'];
        $email     = $claims['email'];
        // $claims['picture'] is deliberately not read. The profile photo is
        // the worker's own choice, never one taken from their Gmail account.

        $existingUser = User::where('email', $email)->first();

        // Deliberately not logging the email or whether an account exists — that
        // combination turns the log into an account-enumeration oracle and puts
        // user PII into plaintext log files.
        \Log::debug('Google login attempt', [
            'is_signup' => $request->boolean('is_signup'),
        ]);

        // If this is a SIGNUP attempt and user exists, reject it
        if ($request->input('is_signup') === true && $existingUser) {
            return $this->fail('This email is already registered. Please login instead.', 422);
        }

        if ($existingUser) {
            /*
                A ban has to hold on every door.

                login() has refused suspended accounts from the start, but this
                path did not — and because suspending deletes the account's
                tokens, the ban itself pushed the user straight back to the
                sign-in screen, where Google handed them a fresh one. The
                suspension revoked the session and then replaced it.
            */
            if ($existingUser->is_suspended) {
                return response()->json([
                    'success' => false,
                    'data' => [
                        'is_suspended'     => true,
                        'suspended_reason' => $existingUser->suspended_reason,
                    ],
                    'message' => 'Account suspended',
                ], 403);
            }

            // Existing user - just log them in (LOGIN flow)
            $existingUser->google_id = $googleId;

            /*
                Google's picture fills a gap, it does not overwrite a choice.

                This assigned the avatar unconditionally on every sign-in, so a
                worker who uploaded a proper photo of themselves got it replaced
                by their Gmail picture the next time they logged in with Google
                - and again every time after. On a hiring app the profile photo
                is what an employer decides on, and it is not the app's place to
                keep swapping it for one taken from somewhere else.

                Only filled when there is nothing there.
            */
            // Not even to fill a gap. An empty photo is the profile asking
            // for one, and filling it silently answers a question the worker
            // never got to hear.

            $existingUser->save();

            $token = $existingUser->createToken('kaya_app')->plainTextToken;
            return $this->ok(['user' => $this->ownAccount($existingUser), 'token' => $token], 'Google login successful');
        }

        // New user attempting to login
        if ($request->input('is_signup') === false) {
            return $this->fail('No account found with this email. Please sign up first.', 404);
        }

        // New user - require password (SIGNUP flow)
        if (!$request->password) {
            return $this->fail('Password is required for new accounts', 422);
        }

        // The name is left unset on purpose: the user chooses it during profile
        // setup, and once an ID is verified it becomes locked to what the
        // document says.
        $user = User::create([
            'name'      => null,
            'email'     => $email,
            'google_id' => $googleId,
            /*
                No avatar from Google.

                A new account used to open with whatever picture happened to be
                on the Gmail address - a group shot, a cartoon, a photo taken
                years ago - already in place as their profile picture, and
                nothing told them it had happened.

                On a hiring app the photo is what an employer decides on, so it
                has to be a picture the worker chose and knows about. Left null
                and the profile asks them to add one.
            */
            'password'  => $request->password,
            'is_verified' => false, // User must complete verification (phone + gmail + valid ID)
            // Recorded because it was required above. Same two columns the
            // email form fills, so consent is stored the same way however the
            // account was made.
            'terms_accepted'    => true,
            'terms_accepted_at' => now(),
        ]);

        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['user' => $this->ownAccount($user), 'token' => $token], 'Account created successfully', 201);
    }

    /**
     * Request password reset — sends email with 6-digit code
     */
    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => ['required', 'email'],
        ]);

        $user = User::where('email', $request->email)->first();

        // Deliberately identical response whether or not the account exists.
        // Returning 404 here turned this endpoint into an account-existence
        // oracle that anyone could enumerate.
        $genericResponse = fn () => $this->ok(
            null,
            'If an account exists for that email, we have sent a reset code.'
        );

        if (!$user) {
            return $genericResponse();
        }

        // Generate 6-digit reset code
        $resetCode = str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);

        // Store hashed token and expiration (15 minutes)
        $user->password_reset_token = Hash::make($resetCode);
        $user->password_reset_expires_at = now()->addMinutes(15);
        $user->save();

        try {
            Mail::to($user->email)->send(new PasswordResetMail($user->name ?? 'User', $resetCode));
        } catch (\Exception $e) {
            // Log the detail for us; never return it to the client, where it can
            // expose mail host, credentials and other internals.
            \Log::error('Failed to send password reset email', [
                'user_id' => $user->id,
                'error'   => $e->getMessage(),
            ]);

            return $this->fail('We could not send the reset email right now. Please try again shortly.', 500);
        }

        return $genericResponse();
    }

    /**
     * Verify reset code
     */
    public function verifyResetCode(Request $request)
    {
        $request->validate([
            'email' => ['required', 'email'],
            'code'  => ['required', 'string', 'size:6'],
        ]);

        $user = User::where('email', $request->email)->first();

        // A missing account, a missing reset request, an expired window and a
        // wrong code all return the same message, so this cannot be used to
        // probe which email addresses exist.
        $invalid = fn () => $this->fail('Invalid or expired reset code. Please request a new one.', 422);

        if (!$user || !$user->password_reset_token || !$user->password_reset_expires_at) {
            return $invalid();
        }

        if (now()->isAfter($user->password_reset_expires_at)) {
            return $invalid();
        }

        if (!Hash::check($request->code, $user->password_reset_token)) {
            return $invalid();
        }

        return $this->ok(null, 'Reset code verified successfully.');
    }

    /**
     * Reset password using verified code
     */
    public function resetPassword(Request $request)
    {
        $request->validate([
            'email'    => ['required', 'email'],
            'code'     => ['required', 'string', 'size:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::where('email', $request->email)->first();

        // A missing account, a missing reset request, an expired window and a
        // wrong code all return the same message, so this cannot be used to
        // probe which email addresses exist.
        $invalid = fn () => $this->fail('Invalid or expired reset code. Please request a new one.', 422);

        if (!$user || !$user->password_reset_token || !$user->password_reset_expires_at) {
            return $invalid();
        }

        if (now()->isAfter($user->password_reset_expires_at)) {
            return $invalid();
        }

        if (!Hash::check($request->code, $user->password_reset_token)) {
            return $invalid();
        }

        // Update password and clear reset token
        $user->password = Hash::make($request->password);
        $user->password_reset_token = null;
        $user->password_reset_expires_at = null;
        $user->save();

        // Revoke all existing tokens for security
        $user->tokens()->delete();

        return $this->ok(null, 'Password reset successful. Please login with your new password.');
    }

    public function user(Request $request)
    {
        return $this->ok([
            'id' => $request->user()->id,
            'name' => $request->user()->name,
            'email' => $request->user()->email,
            'phone' => $request->user()->phone,
            'city' => $request->user()->city,
            'avatar' => $request->user()->avatar,
            'is_verified' => $request->user()->is_verified,
            'user_type' => $request->user()->user_type,
        ], 'User retrieved successfully');
    }
}
