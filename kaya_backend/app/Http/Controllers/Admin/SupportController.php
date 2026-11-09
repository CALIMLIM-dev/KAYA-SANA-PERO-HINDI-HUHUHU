<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\SupportThread;
use App\Services\KayaAssistant;
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
        $this->join($thread);

        return back()->with('success', 'You are handling this chat.');
    }

    /*
        An agent joins: the chat is theirs, the person is told who joined
        and gets a notification, and how long they waited is counted.
    */
    private function join(SupportThread $thread): void
    {
        $me = Auth::user();
        if ((int) $thread->assigned_to === (int) $me->id && $thread->agent_joined_at) {
            return;
        }

        if ($thread->handoff_at && ! $thread->agent_joined_at) {
            KayaAssistant::bump('queue:taken');
            KayaAssistant::bump('queue:wait_seconds', max(0, (int) $thread->handoff_at->diffInSeconds(now())));
        }

        $thread->forceFill(['assigned_to' => $me->id, 'agent_joined_at' => now()])->save();
        KayaAssistant::event($thread, self::firstName($me) . ' from KAYA joined the chat.');

        if ($thread->user) {
            app(NotificationService::class)->supportAgentJoined($thread->user, self::firstName($me));
        }
    }

    private static function firstName(\App\Models\User $user): string
    {
        return explode(' ', trim((string) $user->name))[0] ?: 'A team member';
    }

    /** Take Next: whoever has waited longest. */
    public function takeNext()
    {
        $next = SupportThread::line()->orderBy('handoff_at')->first();
        if (! $next) {
            return back()->with('success', 'Nobody is waiting in line.');
        }

        $this->join($next);

        return redirect()->route('admin.support.show', $next);
    }

    /** Solved: the person keeps chatting with the assistant. */
    public function handBack(SupportThread $thread)
    {
        KayaAssistant::event($thread, self::firstName(Auth::user()) . ' left the chat. KAYA Assistant is back.');
        $thread->forceFill([
            'assigned_to' => null, 'agent_joined_at' => null, 'handoff_at' => null,
            'queue_since' => null, 'queue_saved_until' => null, 'assistant_back_at' => now(),
        ])->save();

        return redirect()->route('admin.support.index')->with('success', 'Handed back to KAYA Assistant.');
    }

    /** Not answering: back in line at the same place, for the next agent. */
    public function putBack(SupportThread $thread)
    {
        KayaAssistant::event($thread, 'A KAYA agent will be with you soon. You keep your place in line.');
        $thread->forceFill(['assigned_to' => null, 'agent_joined_at' => null])->save();

        return redirect()->route('admin.support.index')->with('success', 'Back in line, at the same place.');
    }

    /** Taking support chats right now, or not. With nobody taking them, people are told the team is offline. */
    public function toggleAvailable()
    {
        $me = Auth::user();
        $me->forceFill(['support_available' => ! $me->support_available])->save();

        return back()->with('success', $me->support_available ? 'You are taking support chats.' : 'You are not taking support chats.');
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
                'kind'       => $m->kind,
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

        // Whoever answers first has joined: "Ana joined" comes before her first words.
        if (! $thread->assigned_to || ! $thread->agent_joined_at) {
            $this->join($thread);
        }

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
