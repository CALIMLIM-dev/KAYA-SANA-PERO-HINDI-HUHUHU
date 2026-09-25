<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SupportMessage;
use App\Models\SupportThread;
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

        $messages = $thread
            ? $thread->messages()->orderBy('id')->get()
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
            'messages' => $messages->map(fn ($m) => $this->present($m))->values(),
            'unread'   => 0,
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

    public function send(Request $request, MessageFilter $filter)
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

        return $this->ok($this->present($message), 'Sent', 201);
    }

    private function present(SupportMessage $message): array
    {
        return [
            'id'         => $message->id,
            'body'       => $message->body,
            'from_admin' => $message->from_admin,
            // The name of whoever answered, so a reply reads as a person
            // rather than as the platform. Their own name, not an alias:
            // an admin account is a real account and the audit says so.
            'from'       => $message->from_admin
                ? ($message->sender?->name ?? 'KAYA Support')
                : null,
            'created_at' => $message->created_at->toIso8601String(),
        ];
    }
}
