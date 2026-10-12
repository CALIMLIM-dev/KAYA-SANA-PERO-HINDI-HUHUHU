<?php

namespace App\Services;

use App\Enums\AdminRole;
use App\Models\AdminAction;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/*
    Making an administrator.

    The only way in used to be AdminSeeder, which makes one account from the
    .env. The Administrators page and kaya:make-admin both come here, so
    there is one place that decides what a new admin account looks like.

    The password is generated, never typed: whoever makes the account sees it
    once and hands it over, and the new admin has to replace it at their
    first sign-in (must_change_password), so the one the creator saw stops
    working almost at once.
*/
class AdminAccounts
{
    /**
     * @return array{0: User, 1: string} the account and its one-time password
     */
    public function create(string $name, string $email, AdminRole $role): array
    {
        // Letters and digits only, so it survives being read out or retyped.
        $password = Str::password(16, symbols: false);

        $user = new User();
        $user->forceFill([
            'name'                 => trim($name),
            'email'                => mb_strtolower(trim($email)),
            'password'             => Hash::make($password),
            'user_type'            => 'admin',
            'admin_role'           => $role->value,
            'must_change_password' => true,
            'is_verified'          => true,
            'email_verified_at'    => now(),
        ])->save();

        AdminAction::record(
            'admin.created', 'user', $user->id,
            "Added {$user->name} as {$role->label()}" . (Auth::check() ? '' : ' from the server console'),
            ['role' => $role->value, 'email' => $user->email],
            // From the console nobody is signed in; the new account is the
            // only actor there is, and the summary says where it came from.
            by: Auth::id() ?? $user->id,
        );

        return [$user, $password];
    }
}
