<?php

namespace App\Http\Controllers\Admin;

use App\Enums\AdminRole;
use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

/*
    Who the administrators are, and what each of them may do.

    Only a super admin reaches this screen, which is the point: the ability to
    hand out abilities is itself one, and a moderator who could promote
    themselves would make the other two roles decoration.

    It does not create accounts. An administrator is made the way every other
    account is made and then marked here, so there is one path into the users
    table and one place that decides who is an admin at all.
*/
class AdminTeamController extends Controller
{
    public function index()
    {
        $admins = User::where('user_type', 'admin')
            ->orderBy('name')
            ->get(['id', 'name', 'email', 'admin_role', 'is_suspended', 'last_seen_at']);

        return view('admin.admins.index', [
            'admins' => $admins,
            'roles'  => AdminRole::cases(),
        ]);
    }

    public function setRole(Request $request, User $user)
    {
        $data = $request->validate([
            'admin_role' => ['required', Rule::in(array_column(AdminRole::cases(), 'value'))],
        ]);

        if (! $user->isAdmin()) {
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
