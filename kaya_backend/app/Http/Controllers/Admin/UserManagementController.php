<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\User;
use App\Services\SuspensionService;
use App\Support\ModerationReasons;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class UserManagementController extends Controller
{
    public function index(Request $request)
    {
        // The type rides along so each row's verification badge does not ask
        // for it again (User::verification_state reads it).
        $query = User::where('user_type', '!=', 'admin')
            ->with('employerProfile:id,user_id,employer_type');

        if ($search = $request->get('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        // Filter by profile existence rather than user_type, so hybrid accounts
        // appear under both "Worker" and "Employer".
        if ($type = $request->get('user_type')) {
            match ($type) {
                'worker'   => $query->whereHas('workerProfile'),
                'employer' => $query->whereHas('employerProfile'),
                default    => null,
            };
        }

        if ($status = $request->get('status')) {
            match ($status) {
                'verified'   => $query->where('is_verified', true),
                /*
                    Papers waiting on an admin, not merely unverified.

                    This was "not verified and not suspended", so the filter
                    called Pending listed everybody who had never sent an ID.
                */
                'pending'    => $query->where('is_verified', false)
                    ->whereHas('verifications', fn ($v) => $v->where('status', 'pending')),
                'unverified' => $query->where('is_verified', false)->where('is_suspended', false)
                    ->whereDoesntHave('verifications', fn ($v) => $v->where('status', 'pending')),
                'suspended'  => $query->where('is_suspended', true),
                default      => null,
            };
        }

        $users = $query->latest()->paginate(10)->withQueryString();

        return view('admin.users.index', compact('users'));
    }

    public function show(User $user)
    {
        $user->load([
            'postedJobs' => fn ($q) => $q->latest()->take(5),
            'workerProfile',
            'employerProfile.tinVerifier',
            'certifications',
            'licenses',
            'skills.category',
            'skills.skill.category',
            'experiences',
            'verifications',
        ]);

        return view('admin.users.show', [
            'user'              => $user,
            'balance'           => app(\App\Services\CreditLedger::class)->balance($user),
            'suspensionReasons' => ModerationReasons::SUSPENSION,
            'offenses'          => $user->strikes()->latest()->get(),
            'nextStep'          => app(\App\Services\StrikeService::class)->nextStep($user, 'policy_violation'),
        ]);
    }

    /**
     * Reasons come from the shared catalogue rather than from whatever string
     * the form posted. The old version stored the option's label as the reason,
     * so rewording an option orphaned every account banned under the old text,
     * and a crafted request could store any sentence at all.
     */
    /*
        Serves a certificate or licence scan to an admin.

        These were linked with asset('storage/...'), which only resolves if the
        public symlink exists - a fresh deployment has no such link, so every
        document in the admin was a broken image and the fault looked like a
        missing file rather than a missing symlink.

        Streaming it removes that dependency, and it closes something worse:
        asset() produces a permanent public URL to somebody's PRC licence,
        readable by anyone who ever sees the address. Behind this route it
        needs an admin session.
    */
    public function document(User $user, string $kind, int $id)
    {
        $record = match ($kind) {
            'certification' => $user->certifications()->find($id),
            'licence' => $user->licenses()->find($id),
            default => null,
        };

        abort_if($record === null, 404);

        $path = $record->document_path;
        $disk = Storage::disk(config('filesystems.media'));

        abort_if(blank($path) || ! $disk->exists($path), 404);

        // Inline, so a PDF opens in the browser's viewer and an image renders
        // rather than downloading.
        return $disk->response($path);
    }

    /*
        A suspension straight from the account page, for what cannot wait
        for a report. It is still a strike: it counts, it sends a statement
        of reasons, and it can be appealed. Permanent still needs a second
        administrator - see StrikeService.
    */
    public function suspend(Request $request, User $user, \App\Services\StrikeService $strikes)
    {
        $data = $request->validate([
            'reason_code' => ['required', Rule::in(ModerationReasons::suspensionCodes())],
            'note'        => ['nullable', 'string', 'max:1000'],
        ]);

        $data['note'] = ModerationReasons::noteOr($data['note'] ?? null, ModerationReasons::message($data['reason_code']));

        // An administrator locking out another administrator is not moderation,
        // and there is no way back in through this panel.
        if ($user->isAdmin()) {
            return back()->withErrors(['reason_code' => 'Administrator accounts cannot be suspended.']);
        }

        // The same count Reports use: the same offense costs the same
        // whichever page it was given from.
        $offense = $strikes->issue($user, $data['reason_code'], $data['note'], Auth::user());

        AdminAction::record(
            'user.offense', 'user', $user->id,
            "Gave {$user->name} a violation: " . $offense->actionLabel() . ' (' . $offense->ruleLabel() . ')',
            $data,
        );

        return back()->with('success', "{$user->name}: " . $offense->actionLabel() . '.');
    }

    public function activate(User $user, \App\Services\StrikeService $strikes)
    {
        $strikes->liftSuspension($user);

        AdminAction::record('user.reinstated', 'user', $user->id, "Lifted the suspension on {$user->name}");

        return back()->with('success', "{$user->name} is active again.");
    }
}
