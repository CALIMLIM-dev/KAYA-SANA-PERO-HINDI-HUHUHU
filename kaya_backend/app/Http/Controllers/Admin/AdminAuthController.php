<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AdminAuthController extends Controller
{
    public function showLogin()
    {
        if (Auth::check() && Auth::user()->user_type === 'admin') {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.auth.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        if (!Auth::attempt($credentials)) {
            // Failed admin logins are worth recording on their own merit — this
            // account can read government IDs, so repeated failures are the
            // first sign of someone trying to get in.
            //
            // The email is logged because it is the only way to tell a typo
            // from an attack, and whether the account even exists. The password
            // is never logged, and this is the admin panel rather than a public
            // signup form, so there is no user-enumeration surface to protect.
            \Illuminate\Support\Facades\Log::warning('Admin login failed', [
                'email'         => $credentials['email'],
                'email_exists'  => \App\Models\User::where('email', $credentials['email'])->exists(),
                'ip'            => $request->ip(),
            ]);

            return back()->withErrors(['email' => 'Invalid credentials.'])->onlyInput('email');
        }

        if (Auth::user()->user_type !== 'admin') {
            Auth::logout();
            return back()->withErrors(['email' => 'This account does not have admin access.']);
        }

        $request->session()->regenerate();

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request)
    {
        Auth::logout();
        
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login')->with('message', 'Logged out successfully');
    }
}
