<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Verification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class VerificationController extends Controller
{
    public function index(Request $request)
    {
        $status = $request->get('status', 'pending');

        $verifications = Verification::with('user')
            ->when($status !== 'all', fn ($q) => $q->where('status', $status))
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('admin.verifications.index', compact('verifications', 'status'));
    }

    public function show(Verification $verification)
    {
        $verification->load('user');

        return view('admin.verifications.show', compact('verification'));
    }

    public function approve(Verification $verification)
    {
        $verification->update([
            'status' => 'approved',
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        $verification->user->update(['is_verified' => true]);

        return redirect()->route('admin.verifications.index')
            ->with('success', "{$verification->user->name}'s verification was approved.");
    }

    public function reject(Request $request, Verification $verification)
    {
        $request->validate(['reason' => ['required', 'string', 'max:255']]);

        $verification->update([
            'status' => 'rejected',
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
            'rejection_reason' => $request->get('reason'),
        ]);

        return redirect()->route('admin.verifications.index')
            ->with('success', "{$verification->user->name}'s verification was rejected.");
    }
}
