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

        return view('admin.support.index', compact('threads', 'show', 'waiting') + [
            'assistantOn'    => \App\Services\KayaAssistant::enabled(),
            'assistantToday' => $this->assistantToday(),
        ]);
    }

    /*
        What KAYA Assistant did today, for the card on the Support page:
        answers by model, threads passed to the team, messages the safety
        filter stopped before any model saw them.
    */
    private function assistantToday(): array
    {
        // Counted as it happened: the chats themselves are erased on leaving.
        return \App\Services\KayaAssistant::todayStats();
    }

    public function toggleAssistant()
    {
        $on = ! \App\Services\KayaAssistant::enabled();
        \App\Services\KayaAssistant::setEnabled($on);

        \App\Models\AdminAction::record(
            'assistant.toggled', 'setting', null,
            'Turned KAYA Assistant ' . ($on ? 'on' : 'off'),
        );

        return back()->with('success', 'KAYA Assistant is ' . ($on ? 'on.' : 'off. The team answers everything.'));
    }

    /** Their one thread, opened if they have never written. */
    public function forUser(\App\Models\User $user)
    {
        return redirect()->route('admin.support.show', SupportThread::firstOrCreate(['user_id' => $user->id]));
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

    /*
        Anything said since the id the page already holds.

        Polled by the thread view every few seconds. Returns rendered-safe
        fields rather than the model, so a message cannot carry anything the
        page will treat as markup.
    */
    public function since(Request $request, SupportThread $thread)
    {
        $after = (int) $request->query('after', 0);

        $messages = $thread->messages()
            ->where('id', '>', $after)
            ->with('sender:id,name')
            ->orderBy('id')
            ->get();

        // Reading the page is reading the messages on it.
        $thread->messages()
            ->where('from_admin', false)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json([
            'messages' => $messages->map(fn ($m) => [
                'id'         => $m->id,
                'body'       => $m->body,
                'from_admin' => (bool) $m->from_admin,
                'is_assistant' => (bool) $m->is_assistant,
                'who'        => $m->panelName($thread->user?->name),
                'at'         => $m->created_at->format('M j, g:ia'),
            ])->values(),
        ]);
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
