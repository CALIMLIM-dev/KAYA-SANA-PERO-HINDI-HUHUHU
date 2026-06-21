<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserManagementController extends Controller
{
    public function index(Request $request)
    {
        $query = User::where('user_type', '!=', 'admin');

        if ($search = $request->get('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($type = $request->get('user_type')) {
            $query->where('user_type', $type);
        }

        if ($status = $request->get('status')) {
            match ($status) {
                'verified'   => $query->where('is_verified', true),
                'pending'    => $query->where('is_verified', false)->where('is_suspended', false),
                'suspended'  => $query->where('is_suspended', true),
                default      => null,
            };
        }

        $users = $query->latest()->paginate(10)->withQueryString();

        return view('admin.users.index', compact('users'));
    }

    public function show(User $user)
    {
        $user->load(['postedJobs' => fn ($q) => $q->latest()->take(5)]);

        return view('admin.users.show', compact('user'));
    }

    public function suspend(Request $request, User $user)
    {
        $request->validate(['reason' => ['nullable', 'string', 'max:255']]);

        $user->update([
            'is_suspended' => true,
            'suspended_reason' => $request->get('reason'),
        ]);

        return back()->with('success', "{$user->name} has been suspended.");
    }

    public function activate(User $user)
    {
        $user->update(['is_suspended' => false, 'suspended_reason' => null]);

        return back()->with('success', "{$user->name} has been reactivated.");
    }
}
