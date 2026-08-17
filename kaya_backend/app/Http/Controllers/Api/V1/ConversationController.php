<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\MessageSent;
use App\Events\Realtime\ChatMessagePushed;
use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Services\RealtimeBroadcaster;
use Illuminate\Http\Request;

class ConversationController extends Controller
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
        $user = $request->user();

        $conversations = Conversation::where('status', 'unlocked')
            ->where(fn ($q) => $q->where('employer_id', $user->id)->orWhere('worker_id', $user->id))
            // job.status drives whether the chat can offer location sharing —
            // it is only available on a hire in progress.
            ->with(['job:id,title,status', // last_seen_at drives the chat's activity dot. Both sides are loaded
            // because either party may be the one being looked at.
            'employer:id,name,avatar,is_verified,last_seen_at',
            'worker:id,name,avatar,is_verified,last_seen_at', 'latestMessage'])
            ->withCount(['messages as unread_count' => fn ($q) => $q->where('is_read', false)->where('sender_id', '!=', $user->id)])
            ->orderByDesc('updated_at')
            ->paginate(20);

        $this->attachApplications($conversations->getCollection());

        return $this->ok($conversations);
    }

    /**
     * Attaches each conversation's hire (application_id + status).
     *
     * A hire is identified by job_id AND worker_id together, which an Eloquent
     * relation can't express cleanly under eager loading. Done as one extra
     * query for the whole page rather than one per row.
     */
    private function attachApplications($conversations): void
    {
        if ($conversations->isEmpty()) {
            return;
        }

        $applications = \App\Models\Application::query()
            ->whereIn('job_id', $conversations->pluck('job_id')->unique())
            ->whereIn('worker_id', $conversations->pluck('worker_id')->unique())
            ->get(['id', 'job_id', 'worker_id', 'status']);

        foreach ($conversations as $conversation) {
            // The whereIn pair above is a superset (it can cross job/worker
            // combinations), so match both columns exactly here.
            $match = $applications->first(
                fn ($a) => $a->job_id === $conversation->job_id
                    && $a->worker_id === $conversation->worker_id
            );

            $conversation->application_id = $match?->id;
            $conversation->application_status = $match?->status;
        }
    }

    public function messages(Request $request, Conversation $conversation)
    {
        $user = $request->user();

        if ($conversation->employer_id !== $user->id && $conversation->worker_id !== $user->id) {
            return $this->fail('You do not have permission to view this conversation', 403);
        }

        $messages = $conversation->messages()
            ->with('sender:id,name')
            ->orderBy('created_at')
            ->paginate(50);

        return $this->ok($messages);
    }

    public function sendMessage(Request $request, Conversation $conversation)
    {
        $user = $request->user();

        if ($conversation->employer_id !== $user->id && $conversation->worker_id !== $user->id) {
            return $this->fail('You do not have permission to send messages in this conversation', 403);
        }

        if ($conversation->status === 'locked') {
            return $this->fail('Messaging unlocks once the application is accepted', 403);
        }

        $request->validate([
            'message_text' => ['required', 'string', 'max:2000'],
        ]);

        $message = $conversation->messages()->create([
            'sender_id'    => $user->id,
            'message_text' => trim($request->message_text),
            'is_read'      => false,
        ]);

        $conversation->touch();

        $message->setRelation('conversation', $conversation);
        $message->load('sender:id,name');

        // Straight to both devices on the thread, then the notification row for
        // whoever isn't looking at it.
        app(RealtimeBroadcaster::class)->push(new ChatMessagePushed($message));

        MessageSent::dispatch($message);

        return $this->ok($message, 'Message sent successfully', 201);
    }

    public function markRead(Request $request, Conversation $conversation)
    {
        $user = $request->user();

        if ($conversation->employer_id !== $user->id && $conversation->worker_id !== $user->id) {
            return $this->fail('Forbidden', 403);
        }

        $count = $conversation->messages()
            ->where('sender_id', '!=', $user->id)
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        /*
            Tell the sender their message was seen.

            Without this the ticks only turn on the reader's own device and the
            sender learns nothing until they refetch — which for the person
            waiting is the entire point of the feature. Pushed on the same
            channel the messages themselves use, so no new subscription.

            Only when something actually changed, so opening a thread you have
            already read does not emit anything.
        */
        if ($count > 0) {
            app(RealtimeBroadcaster::class)->push(
                new \App\Events\Realtime\ChatMessagesRead($conversation, $user->id)
            );
        }

        return $this->ok(['marked_read_count' => $count], 'Messages marked as read');
    }
}
