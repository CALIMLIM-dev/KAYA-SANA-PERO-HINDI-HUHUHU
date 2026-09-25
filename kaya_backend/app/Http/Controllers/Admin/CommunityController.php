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
        // Waiting first. Nothing on this screen matters as much as a queue of
        // posts whose authors have paid and are waiting to be let up.
        $show = $request->get('show', 'pending');
        $search = trim((string) $request->get('search'));

        $posts = CommunityPost::query()
            ->with(['user:id,name,email', 'category:id,name', 'remover:id,name'])
            ->when($show === 'pending', fn ($q) => $q->where('status', CommunityPost::STATUS_PENDING))
            ->when($show === 'live', fn ($q) => $q->live())
            ->when($show === 'rejected', fn ($q) => $q->where('status', CommunityPost::STATUS_REJECTED))
            ->when($show === 'ended', fn ($q) => $q->where(fn ($w) => $w
                ->where('status', CommunityPost::STATUS_ENDED)
                ->orWhere(fn ($e) => $e->where('status', CommunityPost::STATUS_LIVE)->where('expires_at', '<=', now()))))
            ->when($show === 'removed', fn ($q) => $q->where('status', CommunityPost::STATUS_REMOVED))
            ->when($search !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('title', 'like', "%{$search}%")
                ->orWhere('body', 'like', "%{$search}%")
                ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"))))
            // The thread under each notice, so an administrator judging a
            // post can see what it attracted without a second screen.
            ->with(['comments' => fn ($q) => $q->live()->with('user:id,name')->orderBy('id')])
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        $counts = [
            'pending'  => CommunityPost::where('status', CommunityPost::STATUS_PENDING)->count(),
            'live'     => CommunityPost::live()->count(),
            'rejected' => CommunityPost::where('status', CommunityPost::STATUS_REJECTED)->count(),
            'removed'  => CommunityPost::where('status', CommunityPost::STATUS_REMOVED)->count(),
        ];

        return view('admin.community.index', compact('posts', 'show', 'search', 'counts'));
    }

    /*
        Let it up.

        The paid days start here rather than at submit: a post that waited
        overnight for somebody to read it has not spent one of the seven it
        was charged for. See the migration.
    */
    public function approve(CommunityPost $post, NotificationService $notifications)
    {
        if ($post->status !== CommunityPost::STATUS_PENDING) {
            return back()->with('error', 'That post has already been dealt with.');
        }

        $post->forceFill([
            'status'      => CommunityPost::STATUS_LIVE,
            'reviewed_at' => now(),
            'reviewed_by' => Auth::id(),
            'expires_at'  => now()->addDays((int) config('kaya.community.days'))->endOfDay(),
        ])->save();

        $notifications->communityPostApproved($post);

        AdminAction::record(
            'community.approved', 'community_post', $post->id,
            "Approved {$post->user->name}'s post \"{$post->title}\"",
            ['user_id' => $post->user_id],
        );

        return back()->with('success', 'Post is on the board.');
    }

    /*
        Refuse it, and give the Barya back.

        A post that never went up delivered nothing, so keeping the charge
        would be charging for a refusal. Reuses the ledger's own refund, so
        the reversal is a line in the history rather than a silent top-up.
    */
    public function reject(Request $request, CommunityPost $post, NotificationService $notifications, \App\Services\CreditLedger $ledger)
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:255']]);

        if ($post->status !== CommunityPost::STATUS_PENDING) {
            return back()->with('error', 'That post has already been dealt with.');
        }

        $post->forceFill([
            'status'         => CommunityPost::STATUS_REJECTED,
            'reviewed_at'    => now(),
            'reviewed_by'    => Auth::id(),
            'removed_reason' => $data['reason'],
            'removed_by'     => Auth::id(),
        ])->save();

        $charge = $post->credit_transaction_id
            ? \App\Models\CreditTransaction::find($post->credit_transaction_id)
            : null;

        if ($charge) {
            $ledger->refund($charge, 'Community post not approved');
        }

        $notifications->communityPostRejected($post, $data['reason']);

        AdminAction::record(
            'community.rejected', 'community_post', $post->id,
            "Rejected {$post->user->name}'s post \"{$post->title}\": {$data['reason']}",
            ['user_id' => $post->user_id, 'reason' => $data['reason']],
        );

        return back()->with('success', 'Post refused, the poster told why, and the Barya returned.');
    }

    /** One comment off a thread, with the poster told nothing - see below. */
    public function removeComment(Request $request, \App\Models\CommunityComment $comment)
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:255']]);

        if (! $comment->isLive()) {
            return back()->with('error', 'That comment is already removed.');
        }

        $comment->forceFill([
            'status'         => \App\Models\CommunityComment::STATUS_REMOVED,
            'removed_reason' => $data['reason'],
            'removed_by'     => Auth::id(),
        ])->save();

        AdminAction::record(
            'community.comment_removed', 'community_comment', $comment->id,
            "Removed a comment on post #{$comment->community_post_id}: {$data['reason']}",
            ['user_id' => $comment->user_id, 'reason' => $data['reason']],
        );

        return back()->with('success', 'Comment removed.');
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
