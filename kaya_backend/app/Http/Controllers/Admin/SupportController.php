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
        $show = in_array($request->get('show'), ['waiting', 'mine', 'answered', 'all'], true) ? $request->get('show') : 'waiting';
        $topic = array_key_exists((string) $request->get('topic'), SupportThread::TOPICS) ? $request->get('topic') : null;
        $me = Auth::id();

        $all = SupportThread::query()
            ->with(['user:id,name,email,is_suspended', 'latestMessage', 'assignee:id,name'])
            ->whereHas('messages')
            ->get();

        $in = fn (string $tab) => $all->filter(fn ($t) => match ($tab) {
            'waiting'  => $t->isWaitingOnUs(),
            'mine'     => (int) $t->assigned_to === (int) $me,
            'answered' => $t->isAnswered(),
            default    => true,
        });
        $counts = collect(['waiting', 'mine', 'answered', 'all'])->mapWithKeys(fn ($tab) => [$tab => $in($tab)->count()]);

        $threads = $in($show)
            ->when($topic, fn ($c) => $c->where('topic', $topic))
            // Longest wait first among the unanswered; newest first otherwise.
            ->sortBy(fn ($t) => $t->isWaitingOnUs()
                ? [0, $t->last_message_at?->timestamp ?? 0]
                : [1, -($t->last_message_at?->timestamp ?? 0)])
            ->values();

        $waiting = $counts['waiting'];

        return view('admin.support.index', compact('threads', 'show', 'waiting', 'counts', 'topic') + [
            'assistantOn'    => \App\Services\KayaAssistant::enabled(),
            'feedback'       => \App\Models\AssistantFeedback::with('user:id,name')->latest('id')->take(20)->get(),
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

    /** Take: this chat is mine, so two people never answer the same person. */
    public function take(SupportThread $thread)
    {
        $thread->forceFill(['assigned_to' => Auth::id()])->save();

        return back()->with('success', 'You are handling this chat.');
    }

    /*
        Close: done. The chat is erased for both sides, as every support chat
        is when it ends; nothing of it is kept.
    */
    public function close(SupportThread $thread)
    {
        $name = $thread->user?->name ?? 'a deleted account';
        $thread->messages()->delete();
        $thread->forceFill(['handoff_at' => null, 'assistant_back_at' => null, 'last_message_at' => null, 'assigned_to' => null, 'topic' => null])->save();

        AdminAction::record('support.closed', 'support_thread', $thread->id, 'Closed the support chat with ' . $name, ['user_id' => $thread->user_id]);

        return redirect()->route('admin.support.index')->with('success', 'Chat closed and erased.');
    }

    /** A reported answer, read and dealt with. */
    public function dismissFeedback(\App\Models\AssistantFeedback $feedback)
    {
        $feedback->delete();

        return back()->with('success', 'Removed from the list.');
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
        if (! $thread->assigned_to) {
            $thread->forceFill(['assigned_to' => Auth::id()])->save();
        }

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
