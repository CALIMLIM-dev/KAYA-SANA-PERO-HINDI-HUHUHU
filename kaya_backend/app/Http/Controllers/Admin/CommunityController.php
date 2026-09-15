<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\CommunityPost;
use App\Models\UserNotification;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/** The community board, and the power to take a post down. */
class CommunityController extends Controller
{
    public function index(Request $request)
    {
        $show = $request->get('show', 'live');
        $search = trim((string) $request->get('search'));

        $posts = CommunityPost::query()
            ->with(['user:id,name,email', 'category:id,name', 'remover:id,name'])
            ->when($show === 'live', fn ($q) => $q->live())
            ->when($show === 'ended', fn ($q) => $q->where(fn ($w) => $w
                ->where('status', CommunityPost::STATUS_ENDED)
                ->orWhere(fn ($e) => $e->where('status', CommunityPost::STATUS_LIVE)->where('expires_at', '<=', now()))))
            ->when($show === 'removed', fn ($q) => $q->where('status', CommunityPost::STATUS_REMOVED))
            ->when($search !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('title', 'like', "%{$search}%")
                ->orWhere('body', 'like', "%{$search}%")
                ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"))))
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        $counts = [
            'live'    => CommunityPost::live()->count(),
            'removed' => CommunityPost::where('status', CommunityPost::STATUS_REMOVED)->count(),
        ];

        return view('admin.community.index', compact('posts', 'show', 'search', 'counts'));
    }

    public function remove(Request $request, CommunityPost $post, NotificationService $notifications)
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:255']]);

        if ($post->status === CommunityPost::STATUS_REMOVED) {
            return back()->with('error', 'That post is already removed.');
        }

        $post->forceFill([
            'status'         => CommunityPost::STATUS_REMOVED,
            'removed_reason' => $data['reason'],
            'removed_by'     => Auth::id(),
        ])->save();

        $notifications->communityPostRemoved($post, $data['reason']);

        AdminAction::record(
            'community.removed', 'community_post', $post->id,
            "Removed {$post->user->name}'s post \"{$post->title}\": {$data['reason']}",
            ['user_id' => $post->user_id, 'reason' => $data['reason']],
        );

        return back()->with('success', 'Post removed and the poster told why.');
    }
}
