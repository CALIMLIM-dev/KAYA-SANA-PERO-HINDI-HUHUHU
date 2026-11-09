<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SupportMessage;
use App\Models\SupportThread;
use App\Services\KayaAssistant;
use App\Services\MessageFilter;
use Illuminate\Http\Request;

/*
    Talking to KAYA.

    One thread per account that keeps going - see the migration for why this
    is not a ticket system and not the conversations table.

    Open to any signed-in account, verified or not, suspended or not. The
    people most likely to need it are the ones something has gone wrong for,
    and gating support behind the verification that is the problem would be
    the app refusing to hear about its own faults.
*/
class SupportController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    /** The thread and everything in it, oldest first. */
    public function show(Request $request)
    {
        $user = $request->user();

        $thread = SupportThread::where('user_id', $user->id)->first();

        /*
            Everything, or only what came after the id the caller holds.

            The screen polls every few seconds. Without a cursor each poll
            re-sent the whole conversation to add one line, which on a long
            thread is the entire history over mobile data, several times a
            minute.

            `after` is optional, so a cold open still gets everything, and the
            response says which mode it answered in - the screen appends after
            a cursored call and replaces after a full one.
        */
        $after = (int) $request->query('after', 0);

        if ($thread && $after === 0 && $thread->last_message_at
            && $thread->last_message_at->lt(now()->subMinutes(30))) {
            app(KayaAssistant::class)->clear($thread);
        }

        $messages = $thread
            ? $thread->messages()
                ->when($after > 0, fn ($q) => $q->where('id', '>', $after))
                ->orderBy('id')
                ->get()
            : collect();

        // Opening the thread is reading it. Only KAYA's side: a person does
        // not mark their own messages read.
        if ($thread) {
            $thread->messages()
                ->where('from_admin', true)
                ->whereNull('read_at')
                ->update(['read_at' => now()]);
        }

        return $this->ok([
            'messages'    => $messages->map(fn ($m) => $this->present($m))->values(),
            'unread'      => 0,
            // So the screen knows whether to append or replace.
            'incremental' => $after > 0,
            'assistant'   => $this->assistantState($thread),
        ]);
    }

    /** How many replies are waiting, for the badge on the help screen. */
    public function unread(Request $request)
    {
        $count = SupportMessage::whereHas(
            'thread',
            fn ($q) => $q->where('user_id', $request->user()->id),
        )
            ->where('from_admin', true)
            ->whereNull('read_at')
            ->count();

        return $this->ok(['unread' => $count]);
    }

    public function send(Request $request, MessageFilter $filter, KayaAssistant $assistant)
    {
        $user = $request->user();

        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
        ]);

        /*
            Swearing is masked; a phone number is not refused.

            The contact rule exists because two users swapping numbers take
            the work off the platform. KAYA is the other side of this thread,
            so there is nothing to take anywhere - and somebody describing a
            problem with their own account often has to quote the number or
            the email it is about.
        */
        $body = $filter->maskProfanity(trim($data['body']));

        $thread = SupportThread::firstOrCreate(['user_id' => $user->id]);

        $message = $thread->messages()->create([
            'sender_id'  => $user->id,
            'from_admin' => false,
            'body'       => $body,
        ]);

        $thread->update(['last_message_at' => now()]);

        /*
            KAYA Assistant answers after the response has gone: the person's
            message is saved and shown at once, and the answer arrives on the
            screen's next poll. Nobody waits on a model to send a message.
        */
        if ($assistant->shouldAnswer($thread)) {
            $threadId = $thread->id;
            $messageId = $message->id;

            dispatch(function () use ($threadId, $messageId) {
                if ($thread = SupportThread::find($threadId)) {
                    app(KayaAssistant::class)->answer($thread, $messageId);
                }
            })->afterResponse();
        }

        return $this->ok($this->present($message), 'Sent', 201);
    }

    /** Talk to a Person: the assistant steps aside until somebody from KAYA answers. */
    public function person(Request $request, KayaAssistant $assistant)
    {
        $thread = SupportThread::firstOrCreate(['user_id' => $request->user()->id]);
        $message = $assistant->handOff($thread);

        return $this->ok([
            'message'   => $message ? $this->present($message) : null,
            'assistant' => $this->assistantState($thread->fresh()),
        ], 'A person will answer');
    }

    /** Left the chat: it is erased, unless it is still with the team. */
    public function end(Request $request, KayaAssistant $assistant)
    {
        $thread = SupportThread::where('user_id', $request->user()->id)->first();
        $cleared = $thread ? $assistant->clear($thread) : true;

        return $this->ok(['cleared' => $cleared], $cleared ? 'Chat cleared' : 'Kept for the team');
    }

    /** Back to KAYA Assistant, from the team. */
    public function assistant(Request $request, KayaAssistant $assistant)
    {
        $thread = SupportThread::firstOrCreate(['user_id' => $request->user()->id]);
        $message = $assistant->resume($thread);

        return $this->ok([
            'message'   => $message ? $this->present($message) : null,
            'assistant' => $this->assistantState($thread->fresh()),
        ], 'KAYA Assistant is back');
    }

    /** A quick question, answered at once. */
    public function quick(Request $request, KayaAssistant $assistant)
    {
        $data = $request->validate(['key' => ['required', 'string', 'max:40']]);
        $user = $request->user();
        $thread = SupportThread::firstOrCreate(['user_id' => $user->id]);

        $pair = $assistant->quick($thread, $user, $data['key']);
        if ($pair === null) {
            return response()->json(['success' => false, 'data' => null, 'message' => 'That question is not available right now.'], 422);
        }

        return $this->ok([
            'messages'  => array_map(fn ($m) => $this->present($m), $pair),
            'assistant' => $this->assistantState($thread->fresh()),
        ]);
    }

    /** What the screen shows about the assistant: on, or with a person. */
    private function assistantState(?SupportThread $thread): array
    {
        $on = KayaAssistant::enabled();

        return [
            'on'          => $on,
            'name'        => KayaAssistant::NAME,
            'with_person' => $on && $thread !== null && ! $thread->assistantActive(),
            // The quick questions, as [{key, label}].
            'quick'       => $on
                ? collect(KayaAssistant::quickQuestions())->map(fn ($label, $key) => ['key' => $key, 'label' => $label])->values()
                : [],
        ];
    }

    private function present(SupportMessage $message): array
    {
        return [
            'id'         => $message->id,
            'body'       => $message->body,
            'from_admin' => $message->from_admin,
            'from_assistant' => (bool) $message->is_assistant,
            // The name of whoever answered, so a reply reads as a person
            // rather than as the platform. Their own name, not an alias:
            // an admin account is a real account and the audit says so.
            'from'       => match (true) {
                (bool) $message->is_assistant => KayaAssistant::NAME,
                $message->from_admin          => $message->sender?->name ?? 'KAYA Support',
                default                       => null,
            },
            'created_at' => $message->created_at->toIso8601String(),
        ];
    }
}
