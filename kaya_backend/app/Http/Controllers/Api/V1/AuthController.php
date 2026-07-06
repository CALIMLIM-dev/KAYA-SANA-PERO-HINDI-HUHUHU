<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Mail;
use App\Mail\PasswordResetMail;

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
            'email'    => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'phone'    => ['nullable', 'string', 'max:20'],
            'city'     => ['nullable', 'string', 'max:255'],
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
                'email'    => null,
                'phone'    => $input,
                'password' => $request->input('password'),
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
                'email'    => $input,
                'password' => $request->input('password'),
            ];
        }

        $user  = User::create($userData);
        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['user' => $user, 'token' => $token], 'Registration successful', 201);
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

        return $this->ok(['user' => $user, 'token' => $token], 'Login successful');
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return $this->ok(null, 'Logged out');
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
            'email' => $user->email,
            'phone' => $user->phone,
            'city' => $user->city,
            'avatar' => $user->avatar,
            'is_verified' => $user->is_verified,
            'user_type' => $user->user_type,
            
            // Employer profile flags
            'employer_profile_exists' => $employerProfile !== null,
            'employer_type' => $employerProfile?->employer_type?->value,
            
            // Worker profile flags
            'worker_profile_exists' => $workerProfile !== null,
            'worker_setup_completed' => $workerProfile?->isSetupCompleted() ?? false,
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
    public function updateMe(Request $request)
    {
        $data = $request->validate([
            'name'  => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:20'],
        ]);

        $user = $request->user();

        if (!empty($data['name'])) {
            $user->name = $data['name'];
        }
        if (array_key_exists('phone', $data) && !empty($data['phone'])) {
            $user->phone = $data['phone'];
        }

        $user->save();

        return $this->ok($user, 'Profile updated');
    }

    /**
     * Google Sign-In — Returns Google user data for app to handle password setup
     */
    public function googleLogin(Request $request)
    {
        $request->validate([
            'google_id'    => ['required', 'string'],
            'name'         => ['nullable', 'string'], // Changed to nullable
            'email'        => ['required', 'email'],
            'avatar'       => ['nullable', 'string'],
            'password'     => ['nullable', 'string', 'min:8'],
            'is_signup'    => ['nullable', 'boolean'], // New parameter to distinguish signup vs login
        ]);

        // Check if user already exists
        $existingUser = User::where('email', $request->email)->first();

        \Log::info('Google Login Debug', [
            'email' => $request->email,
            'is_signup' => $request->input('is_signup'),
            'existing_user' => $existingUser ? 'yes' : 'no',
            'has_password' => $request->password ? 'yes' : 'no',
        ]);

        // If this is a SIGNUP attempt and user exists, reject it
        if ($request->input('is_signup') === true && $existingUser) {
            return $this->fail('This email is already registered. Please login instead.', 422);
        }

        if ($existingUser) {
            // Existing user - just log them in (LOGIN flow)
            $existingUser->google_id = $request->google_id;
            $existingUser->avatar = $request->avatar;
            $existingUser->save();

            $token = $existingUser->createToken('kaya_app')->plainTextToken;
            return $this->ok(['user' => $existingUser, 'token' => $token], 'Google login successful');
        }

        // New user attempting to login
        if ($request->input('is_signup') === false) {
            return $this->fail('No account found with this email. Please sign up first.', 404);
        }

        // New user - require password (SIGNUP flow)
        if (!$request->password) {
            return $this->fail('Password is required for new accounts', 422);
        }

        // Create new user with password
        $user = User::create([
            'name'      => $request->name ?: null, // Allow null name
            'email'     => $request->email,
            'google_id' => $request->google_id,
            'avatar'    => $request->avatar,
            'password'  => $request->password,
            'is_verified' => false, // User must complete verification (phone + gmail + valid ID)
        ]);

        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['user' => $user, 'token' => $token], 'Account created successfully', 201);
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

        if (!$user) {
            return $this->fail('No account found with that email address.', 404);
        }

        // Generate 6-digit reset code
        $resetCode = str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);

        // Store hashed token and expiration (15 minutes)
        $user->password_reset_token = Hash::make($resetCode);
        $user->password_reset_expires_at = now()->addMinutes(15);
        $user->save();

        // Send email
        try {
            Mail::to($user->email)->send(new PasswordResetMail($user->name ?? 'User', $resetCode));
            return $this->ok(null, 'Password reset code sent to your email.');
        } catch (\Exception $e) {
            \Log::error('Failed to send reset email: ' . $e->getMessage());
            return $this->fail('Failed to send reset email: ' . $e->getMessage(), 500);
        }
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

        if (!$user) {
            return $this->fail('No account found with that email address.', 404);
        }

        if (!$user->password_reset_token || !$user->password_reset_expires_at) {
            return $this->fail('No reset request found. Please request a new code.', 422);
        }

        if (now()->isAfter($user->password_reset_expires_at)) {
            return $this->fail('Reset code has expired. Please request a new one.', 422);
        }

        if (!Hash::check($request->code, $user->password_reset_token)) {
            return $this->fail('Invalid reset code. Please check and try again.', 422);
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

        if (!$user) {
            return $this->fail('No account found with that email address.', 404);
        }

        if (!$user->password_reset_token || !$user->password_reset_expires_at) {
            return $this->fail('No reset request found. Please request a new code.', 422);
        }

        if (now()->isAfter($user->password_reset_expires_at)) {
            return $this->fail('Reset code has expired. Please request a new one.', 422);
        }

        if (!Hash::check($request->code, $user->password_reset_token)) {
            return $this->fail('Invalid reset code. Please check and try again.', 422);
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
