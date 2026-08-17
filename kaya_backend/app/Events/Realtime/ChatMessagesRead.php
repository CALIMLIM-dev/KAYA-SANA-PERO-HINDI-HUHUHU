<?php

namespace App\Events\Realtime;

use App\Models\Conversation;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * The other party opened the thread and read what was waiting.
 *
 * Carries no message ids on purpose. "Everything I sent before this moment has
 * been seen" is the whole of what a seen indicator means, and it stays correct
 * even if the payload arrives out of order or the client missed a message —
 * whereas a list of ids has to be complete to be right.
 *
 * Sent on the same channel as the messages themselves, so it needs no extra
 * subscription and cannot arrive on a thread the client is not watching.
 */
class ChatMessagesRead implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(
        public Conversation $conversation,
        public int $readerId,
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('conversation.' . $this->conversation->id)];
    }

    public function broadcastAs(): string
    {
        return 'messages.read';
    }

    public function broadcastWith(): array
    {
        return [
            'conversation_id' => $this->conversation->id,
            // Who did the reading, so the sender can ignore their own reads —
            // both parties receive this frame.
            'reader_id'       => $this->readerId,
            'read_at'         => now()->toIso8601String(),
        ];
    }
}
