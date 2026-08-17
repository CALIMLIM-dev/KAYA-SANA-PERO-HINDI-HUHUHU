<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\UserNotification;
use App\Models\Verification;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

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
            'status' => 'verified',
            'reviewed_by' => Auth::id(),
            'reviewed_at' => now(),
        ]);

        // forceFill: is_verified is intentionally not mass-assignable.
        $verification->user->forceFill(['is_verified' => true])->save();

        app(NotificationService::class)->verificationApproved(
            userId: $verification->user_id,
            audience: $this->audienceFor($verification),
        );

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

        // The reason travels with it. Without it the person is told they failed
        // and left to guess what to change, which usually means resubmitting
        // exactly the same document.
        app(NotificationService::class)->verificationRejected(
            userId: $verification->user_id,
            audience: $this->audienceFor($verification),
            reason: $request->get('reason'),
        );

        return redirect()->route('admin.verifications.index')
            ->with('success', "{$verification->user->name}'s verification was rejected.");
    }

    /**
     * Which side of the app this person will read the notification on.
     *
     * Verification is account-level rather than role-level, so either audience
     * is defensible for a hybrid. Worker is chosen when they have that profile
     * because the verified badge does more there — it is what an employer looks
     * for when choosing between applicants.
     */
    private function audienceFor(Verification $verification): string
    {
        return $verification->user?->workerProfile()->exists()
            ? UserNotification::AUDIENCE_WORKER
            : UserNotification::AUDIENCE_EMPLOYER;
    }

    /**
     * Streams a submitted document to the reviewing administrator.
     *
     * These used to be linked as /storage/... and served straight off disk,
     * which meant a government ID and a liveness selfie were readable by anyone
     * with the URL. They now live on the private disk, so the panel has to ask
     * for them through a route that checks who is asking — which the admin
     * middleware on this group already does.
     */
    public function document(Verification $verification, string $side)
    {
        $column = ['front' => 'document_front_url', 'back' => 'document_back_url', 'selfie' => 'selfie_url'][$side] ?? null;

        abort_if($column === null, 404);

        $path = $verification->{$column};

        abort_if(blank($path) || ! Storage::disk(config('filesystems.documents'))->exists($path), 404);

        return Storage::disk(config('filesystems.documents'))->response($path);
    }
}
