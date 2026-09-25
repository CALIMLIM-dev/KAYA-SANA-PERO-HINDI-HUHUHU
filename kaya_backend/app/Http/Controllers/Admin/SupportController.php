<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\SupportThread;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/*
    The other end of "chat to support".

    Ordered by who has been waiting longest without an answer, because that is
    the only ordering a support queue has ever needed. A thread KAYA has
    already replied to sinks below every thread it has not.
*/
class SupportController extends Controller
{
    public function index(Request $request)
    {
        $show = $request->get('show', 'waiting');

        $threads = SupportThread::query()
            ->with(['user:id,name,email,is_suspended', 'latestMessage'])
            ->whereHas('messages')
            ->get()
            ->filter(fn ($t) => $show === 'all' || $t->isWaitingOnUs())
            // Longest wait first among the unanswered; newest first otherwise.
            ->sortBy(fn ($t) => $t->isWaitingOnUs()
                ? [0, $t->last_message_at?->timestamp ?? 0]
                : [1, -($t->last_message_at?->timestamp ?? 0)])
            ->values();

        $waiting = SupportThread::with('latestMessage')
            ->whereHas('messages')
            ->get()
            ->filter(fn ($t) => $t->isWaitingOnUs())
            ->count();

        return view('admin.support.index', compact('threads', 'show', 'waiting'));
    }

    public function show(SupportThread $thread)
    {
        $thread->load(['user', 'messages.sender:id,name']);

        // Reading it is reading it. Only their side.
        $thread->messages()
            ->where('from_admin', false)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return view('admin.support.show', compact('thread'));
    }

    public function reply(Request $request, SupportThread $thread, NotificationService $notifications)
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
        ]);

        $thread->messages()->create([
            'sender_id'  => Auth::id(),
            'from_admin' => true,
            'body'       => trim($data['body']),
        ]);

        $thread->update(['last_message_at' => now()]);

        // Somebody who wrote to support and heard nothing assumes nobody
        // read it. The notification is what makes the reply a reply.
        if ($thread->user) {
            $notifications->supportReplied($thread->user);
        }

        AdminAction::record(
            'support.replied', 'support_thread', $thread->id,
            'Replied to ' . ($thread->user?->name ?? 'a deleted account') . ' in support',
            ['user_id' => $thread->user_id],
        );

        return back()->with('success', 'Reply sent.');
    }
}
