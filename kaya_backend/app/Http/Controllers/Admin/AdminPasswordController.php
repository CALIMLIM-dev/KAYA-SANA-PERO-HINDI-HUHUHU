<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Support\PasswordRules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/*
    An administrator choosing their own password.

    Reached first by somebody whose account another admin made: the panel
    sends them here until they have replaced the generated one, which the
    person who made the account has seen. Any admin can come back to it.
*/
class AdminPasswordController extends Controller
{
    public function edit(Request $request)
    {
        return view('admin.password.edit', ['forced' => (bool) $request->user()->must_change_password]);
    }

    public function update(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'current_password' => ['required', 'current_password'],
            'password'         => [...PasswordRules::for($user->email, $user->name), 'different:current_password'],
        ]);

        $user->forceFill([
            'password'             => Hash::make($request->input('password')),
            'must_change_password' => false,
        ])->save();

        AdminAction::record('admin.password_changed', 'user', $user->id, "{$user->name} changed their password");

        return redirect()->route('admin.dashboard')->with('success', 'Your password has been changed.');
    }
}
