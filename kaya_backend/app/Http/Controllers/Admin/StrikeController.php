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
        $tab = in_array($request->get('tab'), ['appeals', 'suspended', 'banned', 'all'], true) ? $request->get('tab') : 'appeals';
        $search = trim((string) $request->get('q', ''));

        // Suspended now: a suspension still running. Banned: a ban still standing.
        $scope = fn (string $t) => match ($t) {
            'appeals'   => fn ($q) => $q->where('appeal_status', 'pending'),
            'suspended' => fn ($q) => $q->whereNull('removed_at')->where('action', 'suspension')->where('ends_at', '>', now()),
            'banned'    => fn ($q) => $q->whereNull('removed_at')->where('action', 'ban'),
            default     => fn ($q) => $q,
        };

        $query = Strike::with(['user:id,name,is_suspended', 'issuer:id,name'])
            ->where($scope($tab))
            ->when($search !== '', fn ($q) => $q->whereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%")))
            ->when($tab === 'appeals', fn ($q) => $q->orderBy('appealed_at'))
            ->when($tab === 'suspended', fn ($q) => $q->orderBy('ends_at'))
            ->when(in_array($tab, ['banned', 'all'], true), fn ($q) => $q->latest());

        return view('admin.strikes.index', [
            'tab'     => $tab,
            'search'  => $search,
            'strikes' => $query->paginate(20)->withQueryString(),
            'counts'  => collect(['appeals', 'suspended', 'banned'])->mapWithKeys(fn ($t) => [$t => Strike::where($scope($t))->count()]),
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
        ], ['decision.required' => 'Choose Accept or Refuse.']);

        if ($error = $this->strikes->decideAppeal($strike, Auth::user(), $data['decision'] === 'overturned')) {
            return back()->withErrors(['decision' => $error]);
        }

        AdminAction::record(
            'strike.appeal.' . $data['decision'], 'user', $strike->user_id,
            ($data['decision'] === 'overturned' ? 'Accepted' : 'Refused') . " the appeal on violation #{$strike->id} ({$strike->user?->name})",
            ['strike_id' => $strike->id],
        );

        return back()->with('success', $data['decision'] === 'overturned'
            ? 'Accepted. The violation is removed and the account is no longer limited.'
            : 'Refused. The violation stays.');
    }

    public function remove(Strike $strike)
    {
        if ($error = $this->strikes->remove($strike)) {
            return back()->withErrors(['remove' => $error]);
        }

        AdminAction::record('strike.removed', 'user', $strike->user_id,
            "Removed violation #{$strike->id} from {$strike->user?->name}", ['strike_id' => $strike->id]);

        return back()->with('success', 'Violation removed.');
    }
}
