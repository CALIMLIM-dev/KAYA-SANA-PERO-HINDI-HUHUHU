<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Strike;
use App\Services\StrikeService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/*
    Offenses ("strikes" in the code) and the review requests against them.
    One admin decides, here as everywhere else on the panel.
*/
class StrikeController extends Controller
{
    public function __construct(private StrikeService $strikes) {}

    public function index(Request $request)
    {
        $tab = $request->get('tab', 'appeals') === 'all' ? 'all' : 'appeals';
        $search = trim((string) $request->get('q', ''));

        $query = Strike::with(['user:id,name,is_suspended', 'issuer:id,name'])
            ->when($search !== '', fn ($q) => $q->whereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%")))
            ->when($tab === 'appeals', fn ($q) => $q->where('appeal_status', 'pending')->orderBy('appealed_at'))
            ->when($tab === 'all', fn ($q) => $q->latest());

        return view('admin.strikes.index', [
            'tab'     => $tab,
            'search'  => $search,
            'strikes' => $query->paginate(20)->withQueryString(),
            'counts'  => ['appeals' => Strike::where('appeal_status', 'pending')->count()],
        ]);
    }

    public function show(Strike $strike)
    {
        $strike->load(['user', 'issuer:id,name', 'appealDecider:id,name', 'report']);

        return view('admin.strikes.show', [
            'strike' => $strike,
            'others' => $strike->user
                ? $strike->user->strikes()->where('id', '!=', $strike->id)->latest()->get()
                : collect(),
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
            ($data['decision'] === 'overturned' ? 'Accepted' : 'Refused') . " the review request on offense #{$strike->id} ({$strike->user?->name})",
            ['strike_id' => $strike->id, 'note' => $data['note']],
        );

        return back()->with('success', $data['decision'] === 'overturned'
            ? 'Accepted. The offense is removed and the account is no longer limited.'
            : 'Refused. The offense stays.');
    }

    public function remove(Strike $strike)
    {
        if ($error = $this->strikes->remove($strike)) {
            return back()->withErrors(['remove' => $error]);
        }

        AdminAction::record('strike.removed', 'user', $strike->user_id,
            "Removed offense #{$strike->id} from {$strike->user?->name}", ['strike_id' => $strike->id]);

        return back()->with('success', 'Offense removed.');
    }
}
