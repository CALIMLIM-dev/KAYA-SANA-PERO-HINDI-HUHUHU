<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Strike;
use App\Services\StrikeService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/*
    The second look: appeals, and bans waiting for a second administrator.

    Both are decided by somebody other than the administrator who issued
    the strike - StrikeService refuses otherwise - so neither is one
    person's word.
*/
class StrikeController extends Controller
{
    public function __construct(private StrikeService $strikes) {}

    public function index(Request $request)
    {
        $tab = $request->get('tab', 'appeals');

        $query = Strike::with(['user:id,name,is_suspended', 'issuer:id,name'])
            ->when($tab === 'appeals', fn ($q) => $q->where('appeal_status', 'pending')->orderBy('appealed_at'))
            ->when($tab === 'bans', fn ($q) => $q->where('action', 'ban')->whereNull('confirmed_at')->whereNull('removed_at')->oldest())
            ->when($tab === 'all', fn ($q) => $q->latest());

        return view('admin.strikes.index', [
            'tab'     => $tab,
            'strikes' => $query->paginate(20)->withQueryString(),
            'counts'  => [
                'appeals' => Strike::where('appeal_status', 'pending')->count(),
                'bans'    => Strike::where('action', 'ban')->whereNull('confirmed_at')->whereNull('removed_at')->count(),
            ],
        ]);
    }

    public function show(Strike $strike)
    {
        $strike->load(['user', 'issuer:id,name', 'confirmer:id,name', 'appealDecider:id,name', 'report']);

        return view('admin.strikes.show', [
            'strike' => $strike,
            'others' => $strike->user
                ? $strike->user->strikes()->where('id', '!=', $strike->id)->latest()->get()
                : collect(),
            'mine'   => $strike->issued_by === Auth::id(),
        ]);
    }

    public function decideAppeal(Request $request, Strike $strike)
    {
        $data = $request->validate([
            'decision' => ['required', 'in:upheld,overturned'],
            'note'     => ['required', 'string', 'min:10', 'max:1000'],
        ], ['note.required' => 'Write the reason for your decision; it is sent to them.']);

        if ($error = $this->strikes->decideAppeal($strike, Auth::user(), $data['decision'] === 'overturned', $data['note'])) {
            return back()->withErrors(['note' => $error])->withInput();
        }

        AdminAction::record(
            'strike.appeal.' . $data['decision'], 'user', $strike->user_id,
            ($data['decision'] === 'overturned' ? 'Overturned' : 'Upheld') . " strike #{$strike->id} on appeal ({$strike->user?->name})",
            ['strike_id' => $strike->id, 'note' => $data['note']],
        );

        return redirect()->route('admin.strikes.index')->with('success', $data['decision'] === 'overturned'
            ? 'Appeal accepted. The strike is removed and what it limited is lifted.'
            : 'Appeal refused. The strike stands.');
    }

    public function confirmBan(Strike $strike)
    {
        if ($error = $this->strikes->confirmBan($strike, Auth::user())) {
            return back()->withErrors(['ban' => $error]);
        }

        AdminAction::record('strike.ban.confirmed', 'user', $strike->user_id,
            "Confirmed the permanent ban of {$strike->user?->name} (strike #{$strike->id})", ['strike_id' => $strike->id]);

        return redirect()->route('admin.strikes.index', ['tab' => 'bans'])->with('success', 'Ban confirmed. It is now permanent.');
    }

    public function declineBan(Strike $strike)
    {
        if ($error = $this->strikes->declineBan($strike, Auth::user())) {
            return back()->withErrors(['ban' => $error]);
        }

        AdminAction::record('strike.ban.declined', 'user', $strike->user_id,
            "Declined a permanent ban of {$strike->user?->name}; it stays a " . config('moderation.ban_hold_days') . "-day suspension (strike #{$strike->id})",
            ['strike_id' => $strike->id]);

        return redirect()->route('admin.strikes.index', ['tab' => 'bans'])
            ->with('success', 'Ban declined. It stays a ' . config('moderation.ban_hold_days') . '-day suspension.');
    }
}
