<?php

namespace App\Services;

use App\Events\Realtime\ChatMessagePushed;
use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;

/*
    The job's history, written into the chat.

    A hire, a side confirming the work is done, the job finishing, a hire
    ending early: each lands in the thread as a system row, the way a
    shop's chat carries the order's history. Scrolling back then says what
    happened and when, instead of the messages just stopping.

    A system row has a sender (the person whose action it was) so the
    schema holds, and a type so the app draws it centred rather than as a
    bubble. It is pushed to open chats like any message but never raises a
    "new message" notification: the event it records already sent its own.
*/
class ChatEvents
{
    public const TYPE_SYSTEM = 'system';

    public function hired(Conversation $conversation, JobPost $job, User $employer, User $worker): void
    {
        $this->write($conversation, $employer, 'hired', $job,
            $employer->name . ' hired ' . $worker->name . '.');
    }

    public function confirmed(Conversation $conversation, JobPost $job, User $by): void
    {
        $this->write($conversation, $by, 'confirmed', $job,
            $by->name . ' marked the job as done. Waiting for the other side to confirm.');
    }

    public function completed(Conversation $conversation, JobPost $job, User $by): void
    {
        $this->write($conversation, $by, 'completed', $job,
            'Both sides confirmed. The job is complete.');
    }

    public function ended(Conversation $conversation, JobPost $job, User $by, string $why): void
    {
        $this->write($conversation, $by, 'ended', $job, $why);
    }

    /** The thread between a job's employer and one of its hires, if there is one. */
    public function threadFor(JobPost $job, Application $application): ?Conversation
    {
        return Conversation::where('pair_low', min($job->employer_id, $application->worker_id))
            ->where('pair_high', max($job->employer_id, $application->worker_id))
            ->first();
    }

    private function write(Conversation $conversation, User $by, string $event, JobPost $job, string $text): void
    {
        $message = $conversation->messages()->create([
            'sender_id'    => $by->id,
            'message_text' => $text,
            'is_read'      => false,
            'type'         => self::TYPE_SYSTEM,
            'payload'      => [
                'event'      => $event,
                'job_id'     => $job->id,
                'job_title'  => $job->title,
                'job_status' => $job->status,
            ],
        ]);

        $conversation->touch();

        $message->setRelation('conversation', $conversation);
        $message->load(['sender:id,name,avatar']);

        try {
            app(RealtimeBroadcaster::class)->push(new ChatMessagePushed($message));
        } catch (\Throwable) {
            // Reverb is off on the server. The poll picks it up.
        }
    }
}
