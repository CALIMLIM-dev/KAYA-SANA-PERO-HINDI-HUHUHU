<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

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
        $data = $request->validate([
            'name'      => ['required', 'string', 'max:255'],
            'email'     => ['required', 'email', 'unique:users'],
            'password'  => ['required', 'string', 'min:8', 'confirmed'],
            'user_type' => ['required', Rule::in(['worker', 'employer'])],
            'phone'     => ['nullable', 'string', 'max:20'],
            'city'      => ['nullable', 'string', 'max:255'],
        ]);

        $user  = User::create($data);
        $token = $user->createToken('kaya_app')->plainTextToken;

        return $this->ok(['user' => $user, 'token' => $token], 'Registration successful', 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (!$user || !Hash::check($data['password'], $user->password)) {
            return $this->fail('Invalid credentials', 401);
        }

        if ($user->is_suspended) {
            return $this->fail('Your account has been suspended.', 403);
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
        return $this->ok($request->user());
    }
}
