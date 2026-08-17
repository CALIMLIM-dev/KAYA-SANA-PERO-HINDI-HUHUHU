<?php

namespace App\Events\Realtime;

use App\Models\Message;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * A chat message, pushed to both parties on the thread.
 *
 * The sender receives it too. That is deliberate: it is how the sender's own
 * optimistic bubble gets reconciled with the server's real id and timestamp,
 * and it keeps a second device signed into the same account in step. The client
 * de-duplicates on `id`.
 */
class ChatMessagePushed implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(public Message $message) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('conversation.' . $this->message->conversation_id)];
    }

    public function broadcastAs(): string
    {
        return 'message.created';
    }

    public function broadcastWith(): array
    {
        return [
            'id'              => $this->message->id,
            'conversation_id' => $this->message->conversation_id,
            'sender_id'       => $this->message->sender_id,
            'sender_name'     => $this->message->sender?->name,
            'message_text'    => $this->message->message_text,
            'is_read'         => (bool) $this->message->is_read,
            'created_at'      => $this->message->created_at?->toIso8601String(),
        ];
    }
}
