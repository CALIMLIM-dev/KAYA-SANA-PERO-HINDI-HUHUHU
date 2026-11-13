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
            ->whereNull('kind')
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
        $data = $request->validate(['topic' => ['nullable', 'string', \Illuminate\Validation\Rule::in(array_keys(SupportThread::TOPICS))]]);
        $thread = SupportThread::firstOrCreate(['user_id' => $request->user()->id]);
        if (! empty($data['topic'])) {
            $thread->forceFill(['topic' => $data['topic']])->save();
        }
        $message = $assistant->handOff($thread);

        return $this->ok([
            'message'   => $message ? $this->present($message) : null,
            'assistant' => $this->assistantState($thread->fresh()),
        ], 'A person will answer');
    }

    /*
        The feedback button on a KAYA Assistant answer. A copy of the answer
        and the question before it goes to the team, since the chat itself
        is erased when the person leaves.
    */
    public function feedback(Request $request)
    {
        $data = $request->validate(['message_id' => ['required', 'integer']]);
        $user = $request->user();
        $thread = SupportThread::where('user_id', $user->id)->first();

        $answer = $thread?->messages()->whereKey($data['message_id'])->where('is_assistant', true)->first();
        if (! $answer) {
            return response()->json(['success' => false, 'data' => null, 'message' => 'That answer is no longer here.'], 404);
        }

        $question = $thread->messages()->where('id', '<', $answer->id)->where('from_admin', false)->latest('id')->value('body');

        \App\Models\AssistantFeedback::firstOrCreate(
            ['user_id' => $user->id, 'message_id' => $answer->id],
            ['question' => $question, 'answer' => $answer->body, 'model' => $answer->assistant_model],
        );

        return $this->ok(null, 'Thanks. The KAYA team will look at this answer.');
    }

    /** Left the chat: it is erased, unless it is still with the team. */
    public function end(Request $request, KayaAssistant $assistant)
    {
        $thread = SupportThread::where('user_id', $request->user()->id)->first();
        $cleared = $thread ? $assistant->clear($thread) : true;

        return $this->ok(['cleared' => $cleared], $cleared ? 'Chat cleared' : 'Kept for the team');
    }

    /*
        A tap in KAYA Assistant's menu: a topic, an issue, Yes Solved, Talk to
        an Agent. Answered at once, from the menu and the person's own records.
    */
    public function choose(Request $request, \App\Services\SupportFlow $flow, KayaAssistant $assistant)
    {
        $data = $request->validate(['key' => ['required', 'string', 'max:80']]);
        $user = $request->user();
        $thread = SupportThread::firstOrCreate(['user_id' => $user->id]);

        // A button no longer showing, or tapped twice: nothing new is written.
        if (! $flow->current($thread, $data['key'])) {
            return $this->ok(['messages' => [], 'assistant' => $this->assistantState($thread)]);
        }

        if ($data['key'] === 'agent') {
            $messages = [$assistant->handOff($thread)];
        } else {
            $pair = $flow->choose($thread, $user, $data['key']);
            if ($pair === null) {
                return response()->json(['success' => false, 'data' => null, 'message' => 'That choice is not available.'], 422);
            }
            $messages = $pair;
        }

        return $this->ok([
            'messages'  => collect($messages)->filter()->map(fn ($m) => $this->present($m))->values(),
            'assistant' => $this->assistantState($thread->fresh()),
        ]);
    }

    /*
        Something's Broken: what happened, where, a few words and an optional
        screenshot. KAYA adds the server errors on this account from the last
        ten minutes, so nobody has to describe anything technical.
    */
    public function bug(Request $request)
    {
        $data = $request->validate([
            'issue'       => ['required', \Illuminate\Validation\Rule::in(array_keys(\App\Models\BugReport::ISSUES))],
            'screen'      => ['required', \Illuminate\Validation\Rule::in(array_keys(\App\Models\BugReport::SCREENS))],
            'details'     => ['nullable', 'string', 'max:1000'],
            'app_version' => ['nullable', 'string', 'max:20'],
            'device'      => ['nullable', 'string', 'max:120'],
            'screenshot'  => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ]);
        $user = $request->user();

        $report = \App\Models\BugReport::create([
            'user_id'          => $user->id,
            'issue'            => $data['issue'],
            'screen'           => $data['screen'],
            'details'          => isset($data['details']) ? app(MessageFilter::class)->maskProfanity(trim($data['details'])) : null,
            'app_version'      => $data['app_version'] ?? null,
            'device'           => $data['device'] ?? null,
            'screenshot_path'  => $request->file('screenshot')?->store('bug_reports', config('filesystems.documents')),
            'server_error_ids' => \App\Models\ServerError::where('user_id', $user->id)
                ->where('last_seen_at', '>=', now()->subMinutes(10))->pluck('id')->all(),
        ]);

        // Said in the chat, so the person sees it went through.
        $thread = SupportThread::firstOrCreate(['user_id' => $user->id]);
        $line = $thread->messages()->create([
            'sender_id' => null, 'from_admin' => true, 'is_assistant' => true, 'assistant_model' => 'menu',
            'body' => 'Thank you. Your report was sent to the KAYA team. We will tell you when it is fixed.',
        ]);
        $thread->forceFill(['last_message_at' => now()])->save();

        return $this->ok(['id' => $report->id, 'message' => $this->present($line)], 'Report sent', 201);
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

    private function lineState(?SupportThread $thread): ?array
    {
        $place = $thread?->placeInLine();
        if ($place === null) {
            return null;
        }

        $average = SupportThread::averageWaitSeconds();

        return [
            'position'    => $place,
            'eta_minutes' => $average === null ? null : max(1, (int) ceil($average * $place / 60)),
        ];
    }

    /** What the screen shows about the assistant: on, or with a person. */
    private function assistantState(?SupportThread $thread): array
    {
        $on = KayaAssistant::enabled();

        return [
            'on'          => $on,
            'name'        => KayaAssistant::NAME,
            'with_person' => $on && $thread !== null && ! $thread->assistantActive(),
            // The line: place, a rough wait, the agent once one joins.
            'line'        => $this->lineState($thread),
            'agent'       => $thread?->agent_joined_at && $thread->assignee
                ? explode(' ', trim((string) $thread->assignee->name))[0]
                : null,
            'team_online' => SupportThread::teamOnline(),
            /*
                Known issues the team posted, pinned at the top of the chat.
                They used to appear only after somebody tapped the matching
                topic, so a posted notice looked like it did nothing.
            */
            'notices'     => \App\Models\KnownIssue::where('active', true)->latest('id')->take(3)->get()
                ->map(fn ($issue) => [
                    'text'  => $issue->text,
                    'topic' => $issue->topic ? (\App\Services\SupportFlow::menu()[$issue->topic]['label'] ?? null) : null,
                ])->values(),
            // The menu the greeting offers, and the greeting itself.
            'greeting'    => \App\Services\SupportFlow::greeting(),
            'menu'        => \App\Services\SupportFlow::topicOptions(),
            // The topics for Talk to a Person, as [{key, label}].
            'topics'      => collect(SupportThread::TOPICS)->map(fn ($label, $key) => ['key' => $key, 'label' => $label])->values(),
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
            'from_assistant' => (bool) $message->is_assistant && ! $message->isEvent(),
            // 'event': a line between the two sides, shown as a divider.
            'kind'       => $message->kind,
            // Buttons on an assistant line: options to tap, screens to open.
            'payload'    => $message->payload,
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
