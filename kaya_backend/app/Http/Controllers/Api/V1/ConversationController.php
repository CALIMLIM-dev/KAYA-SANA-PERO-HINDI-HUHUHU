<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
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
            ->with(['job:id,title', 'employer:id,name,profile_picture,is_verified', 'worker:id,name,profile_picture,is_verified'])
            ->withCount(['messages as unread_count' => fn ($q) => $q->where('is_read', false)->where('sender_id', '!=', $user->id)])
            ->orderByDesc('updated_at')
            ->paginate(20);

        return $this->ok($conversations);
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

        return $this->ok($message->load('sender:id,name'), 'Message sent successfully', 201);
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
            ->update(['is_read' => true]);

        return $this->ok(['marked_read_count' => $count], 'Messages marked as read');
    }
}
