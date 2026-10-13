<?php

namespace App\Http\Controllers\Admin;

use App\Enums\AdminRole;
use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\User;
use App\Services\AdminAccounts;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/*
    Who the administrators are, and what each of them may do.

    Only a super admin reaches this screen, which is the point: the ability to
    hand out abilities is itself one, and a moderator who could promote
    themselves would make the other two roles decoration.

    New administrators are made here too (AdminAccounts): a generated password,
    shown once on the next page and never again, which the new admin replaces
    at their first sign-in.

    And unmade: renamed, or removed. Removing closes the account rather than
    deleting the row, because the audit log points at it - a deleted row would
    take every line of that admin's history with it (admin_actions cascades).
    The name stays so the log still says who; the email is freed so the same
    person can be added again later.
*/
class AdminTeamController extends Controller
{
    public function index()
    {
        $admins = User::where('user_type', 'admin')
            ->whereNull('deleted_at')
            ->orderBy('name')
            ->get(['id', 'name', 'email', 'admin_role', 'is_suspended', 'last_seen_at', 'must_change_password']);

        return view('admin.admins.index', [
            'admins' => $admins,
            'roles'  => AdminRole::cases(),
        ]);
    }

    public function store(Request $request, AdminAccounts $accounts)
    {
        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'email'      => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'admin_role' => ['required', Rule::in(array_column(AdminRole::cases(), 'value'))],
        ]);

        [$user, $password] = $accounts->create($data['name'], $data['email'], AdminRole::from($data['admin_role']));

        // Flashed: on the next page and gone after it. Nothing else keeps it.
        return redirect()->route('admin.admins.index')->with('created', [
            'name'     => $user->name,
            'email'    => $user->email,
            'role'     => AdminRole::from($user->admin_role)->label(),
            'password' => $password,
        ]);
    }

    public function rename(Request $request, User $user)
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:255']]);

        if (! $user->isAdmin() || $user->deleted_at) {
            return back()->with('error', 'That account is not an administrator.');
        }

        $was = $user->name;
        $name = trim($data['name']);

        if ($name === $was) {
            return back();
        }

        $user->forceFill(['name' => $name])->save();

        AdminAction::record('admin.renamed', 'user', $user->id, "Renamed administrator {$was} to {$name}", ['from' => $was, 'to' => $name]);

        return back()->with('success', "{$was} is now {$name}.");
    }

    public function remove(User $user)
    {
        if (! $user->isAdmin() || $user->deleted_at) {
            return back()->with('error', 'That account is not an administrator.');
        }

        if ($user->id === Auth::id()) {
            return back()->with('error', 'You cannot remove yourself.');
        }

        /*
            No "last super admin" check is needed: only a super admin reaches
            this, and nobody removes themselves, so one always remains.
        */
        $role = AdminRole::fromUser($user->admin_role);

        $email = $user->email;

        DB::transaction(function () use ($user) {
            $user->tokens()->delete();
            $user->forceFill([
                'email'                => 'removed-' . $user->id . '@deleted.kaya',
                'password'             => Hash::make(Str::random(40)),
                'must_change_password' => false,
                'deleted_at'           => now(),
            ])->save();
        });

        AdminAction::record(
            'admin.removed', 'user', $user->id,
            "Removed administrator {$user->name} ({$role->label()})",
            ['email' => $email, 'role' => $role->value],
        );

        return back()->with('success', "{$user->name} has been removed and can no longer sign in.");
    }

    public function setRole(Request $request, User $user)
    {
        $data = $request->validate([
            'admin_role' => ['required', Rule::in(array_column(AdminRole::cases(), 'value'))],
        ]);

        if (! $user->isAdmin() || $user->deleted_at) {
            return back()->with('error', 'That account is not an administrator.');
        }

        /*
            Nobody demotes themselves.

            The panel would still have other supers in theory, and in practice
            this is a capstone with one of them - so the click that removes
            your own last key locks the whole panel. Refused rather than
            confirmed, because a confirmation dialog on an irreversible
            single-account mistake is not a safeguard.
        */
        if ($user->id === Auth::id()) {
            return back()->with('error', 'You cannot change your own access.');
        }

        $was = AdminRole::fromUser($user->admin_role);
        $now = AdminRole::from($data['admin_role']);

        if ($was === $now) {
            return back()->with('error', $user->name . ' is already a ' . $now->label() . '.');
        }

        $user->forceFill(['admin_role' => $now->value])->save();

        AdminAction::record(
            'admin.role_changed', 'user', $user->id,
            "Changed {$user->name} from {$was->label()} to {$now->label()}",
            ['from' => $was->value, 'to' => $now->value],
        );

        return back()->with('success', $user->name . ' is now a ' . $now->label() . '.');
    }
}
