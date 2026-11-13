<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Http\Request;

/*
    Block and unblock, and the list to unblock from (Settings).

    Blocking is quiet: the other person is not told. It hides both people
    from each other everywhere (App\Support\Blocks); it is not a report,
    and reporting stays a separate button for anything that needs the team.
*/
class BlockController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function index(Request $request)
    {
        $blocked = UserBlock::where('blocker_id', $request->user()->id)
            ->with('blocked:id,name,avatar')
            ->latest('id')
            ->get()
            ->filter(fn ($b) => $b->blocked !== null)
            ->map(fn ($b) => ['id' => $b->blocked->id, 'name' => $b->blocked->name, 'blocked_at' => $b->created_at?->toIso8601String()])
            ->values();

        return $this->ok($blocked);
    }

    public function block(Request $request, User $user)
    {
        $me = $request->user();
        if ($me->id === $user->id) {
            return $this->fail('You cannot block yourself.', 422);
        }

        $block = UserBlock::firstOrCreate(['blocker_id' => $me->id, 'blocked_id' => $user->id]);

        return $this->ok(null, "Blocked {$user->name}. You will not see each other on KAYA.", $block->wasRecentlyCreated ? 201 : 200);
    }

    public function unblock(Request $request, User $user)
    {
        UserBlock::where('blocker_id', $request->user()->id)->where('blocked_id', $user->id)->delete();

        return $this->ok(null, "Unblocked {$user->name}.");
    }
}
