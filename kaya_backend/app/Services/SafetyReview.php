<?php

namespace App\Services;

use App\Events\Realtime\ChatMessagePushed;
use App\Events\MessageSent;
use App\Models\CommunityComment;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Review;
use App\Models\User;

/*
    What the AI safety check does to each kind of thing people write.

    Chat messages and community comments are held from the other side until
    checked (a few seconds; never past moderation.ai.hold_seconds), then
    delivered, or hidden behind a notice. Job posts and reviews are already
    up when checked, so a bad one is reported for the team rather than
    hidden by a model.

    Runs after the response, so nobody waits on it to send.
*/
class SafetyReview
{
    public function __construct(private SafetyCheck $check)
    {
    }

    /** Lines the same sender wrote just before, read with the new one. */
    private function earlierLines($query, int $beforeId, string $column): array
    {
        return $query->where('id', '<', $beforeId)
            ->where('created_at', '>=', now()->subMinutes((int) config('moderation.ai.context_minutes')))
            ->orderByDesc('id')
            ->limit((int) config('moderation.ai.context_lines'))
            ->pluck($column)
            ->reverse()
            ->values()
            ->all();
    }

    public function message(int $id): void
    {
        $message = Message::with('conversation')->find($id);
        if (! $message || $message->checked_at) {
            return;
        }

        $verdict = ($message->type ?? 'text') === 'text'
            ? $this->check->check((string) $message->message_text, $this->earlierLines(
                Message::where('conversation_id', $message->conversation_id)
                    ->where('sender_id', $message->sender_id)
                    ->whereNull('hidden_reason'),
                $message->id,
                'message_text',
            ))
            : SafetyCheck::OK;

        if ($verdict !== null && $verdict !== SafetyCheck::OK) {
            $original = (string) $message->message_text;
            $message->forceFill([
                'message_text'  => SafetyCheck::VERDICTS[$verdict],
                'hidden_reason' => $verdict,
            ]);
            SafetyCheck::count('hidden');
            $this->reportIfNeeded($message->sender_id, 'message', $message->id, $verdict, $original, 'Message');
        }

        $message->forceFill(['checked_at' => now()])->save();

        self::deliver($message);
    }

    /** The push and the notification, once the message is fit to deliver. */
    public static function deliver(Message $message): void
    {
        $message->loadMissing(['conversation', 'sender:id,name,avatar']);
        try {
            app(RealtimeBroadcaster::class)->push(new ChatMessagePushed($message));
        } catch (\Throwable $e) {
            report($e);
        }
        MessageSent::dispatch($message);
    }

    public function comment(int $id): void
    {
        $comment = CommunityComment::find($id);
        if (! $comment || $comment->checked_at) {
            return;
        }

        $verdict = $this->check->check((string) $comment->body, $this->earlierLines(
            CommunityComment::where('community_post_id', $comment->community_post_id)->where('user_id', $comment->user_id),
            $comment->id,
            'body',
        ));

        if ($verdict !== null && $verdict !== SafetyCheck::OK) {
            $original = (string) $comment->body;
            $comment->forceFill([
                'status'         => CommunityComment::STATUS_REMOVED,
                'removed_reason' => SafetyCheck::VERDICTS[$verdict],
            ]);
            SafetyCheck::count('hidden');
            $this->reportIfNeeded($comment->user_id, 'community_comment', $comment->id, $verdict, $original, 'Community Comment');
        }

        $comment->forceFill(['checked_at' => now()])->save();
    }

    public function jobPost(int $id): void
    {
        $job = JobPost::find($id);
        if (! $job) {
            return;
        }

        $text = trim($job->title . "\n" . $job->description);
        $verdict = $this->check->check($text);

        if ($verdict !== null && $verdict !== SafetyCheck::OK && $job->employer) {
            $this->check->report($job->employer, 'job', $job->id, $verdict, $text, 'Job Post');
        }
    }

    public function review(int $id): void
    {
        $review = Review::withoutGlobalScopes()->find($id);
        if (! $review || trim((string) $review->comment) === '') {
            return;
        }

        $verdict = $this->check->check((string) $review->comment);
        $author = User::find($review->reviewer_id);

        if ($verdict !== null && $verdict !== SafetyCheck::OK && $author) {
            $this->check->report($author, 'review', $review->id, $verdict, (string) $review->comment, 'Review');
        }
    }

    /*
        Serious kinds go to the team at once. Contact sharing is hidden, and
        reported only when somebody keeps at it the same day: one slip is a
        habit from other apps, three is trying.
    */
    private function reportIfNeeded(int $senderId, string $type, int $subjectId, string $verdict, string $original, string $kind): void
    {
        $sender = User::find($senderId);
        if (! $sender) {
            return;
        }

        if (in_array($verdict, SafetyCheck::SERIOUS, true)) {
            $this->check->report($sender, $type, $subjectId, $verdict, $original, $kind);

            return;
        }

        if ($this->check->contactStrikeToday($sender) === (int) config('moderation.ai.report_after_hidden')) {
            $this->check->report($sender, $type, $subjectId, $verdict, $original, $kind);
        }
    }
}
