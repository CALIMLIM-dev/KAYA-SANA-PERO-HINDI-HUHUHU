<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\MessageSent;
use App\Events\Realtime\ChatMessagePushed;
use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Services\JobCompletionService;
use App\Services\RealtimeBroadcaster;
use Illuminate\Http\Request;

/*
    The people on a job, as one list.

    A job for one worker is managed from the applicant list and a chat. A
    job for five is not: the employer has to see who is on it and where
    each one stands, mark the lot finished when the work is, and tell all
    of them the same thing at once. That is the roster.

    Not a group chat, on purpose. Each worker keeps their own thread with
    the employer and never sees the others; a broadcast is the same
    message written into each thread, from the employer, as if typed.
*/
class RosterController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function show(Request $request, JobPost $job, JobCompletionService $completion)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $hires = $job->hires()
            ->with(['worker:id,name,avatar,is_verified,phone', 'worker.workerProfile:id,user_id,profile_photo_path,rating_avg,rating_count'])
            ->orderBy('updated_at')
            ->get();

        // Every thread this employer is in, keyed by pair, so each hire's
        // row can carry its chat without a query apiece.
        $threads = Conversation::query()
            ->where(fn ($q) => $q->where('employer_id', $user->id)->orWhere('worker_id', $user->id))
            ->get(['id', 'pair_low', 'pair_high'])
            ->keyBy(fn ($c) => $c->pair_low . '-' . $c->pair_high);

        return $this->ok([
            'job' => [
                'id'             => $job->id,
                'title'          => $job->title,
                'status'         => $job->status,
                'workers_needed' => max(1, (int) $job->workers_needed),
                'workers_filled' => $hires->count(),
                'start_date'     => $job->start_date?->toDateString(),
                'end_date'       => $job->end_date?->toDateString(),
            ],
            'hires' => $hires->map(function (Application $hire) use ($user, $threads, $completion) {
                $key = min($user->id, $hire->worker_id) . '-' . max($user->id, $hire->worker_id);

                return [
                    'application_id'  => $hire->id,
                    'worker_id'       => $hire->worker_id,
                    'name'            => $hire->worker?->name,
                    'avatar'          => $hire->worker?->resolvedAvatarUrl(),
                    'is_verified'     => (bool) $hire->worker?->is_verified,
                    'rating_avg'      => $hire->worker?->workerProfile?->rating_avg,
                    'rating_count'    => (int) ($hire->worker?->workerProfile?->rating_count ?? 0),
                    'status'          => $hire->status,
                    'completion'      => $completion->state($hire, JobCompletionService::SIDE_EMPLOYER),
                    'conversation_id' => $threads[$key]?->id,
                    'hired_at'        => $hire->updated_at?->toIso8601String(),
                ];
            })->values(),
        ]);
    }

    /*
        Marks every hire finished from the employer's side.

        The same two-sided rule as marking one: each worker still confirms
        their own, and the job settles when everyone has. This just saves
        tapping through five threads to say the same thing five times.
    */
    public function completeAll(Request $request, JobPost $job, JobCompletionService $completion)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        // Not before the work was due to finish. See JobPost::deadline.
        if ($why = $job->completionRefusal()) {
            return $this->fail($why, 422);
        }

        $open = $job->hires()->where('status', 'accepted')->get();

        if ($open->isEmpty()) {
            return $this->fail('Nobody on this job is still waiting to be marked complete.', 422);
        }

        $recorded = 0;
        foreach ($open as $hire) {
            $hire->loadMissing('job');
            $completion->confirm($hire, JobCompletionService::SIDE_EMPLOYER);
            if ($completion->lastConfirmationWasNew) {
                $recorded++;
            }
        }

        return $this->ok(
            ['marked' => $recorded, 'job_status' => $job->fresh()->status],
            $recorded === 0
                ? 'You had already marked everyone complete. Waiting on them.'
                : "Marked {$recorded} complete. Each worker confirms their own side.",
        );
    }

    /** One message, written into every hire's thread. */
    public function broadcast(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        if (in_array($job->status, ['completed', 'closed'], true)) {
            return $this->fail('This job is finished. The threads on it are closed.', 422);
        }

        $data = $request->validate(['message_text' => ['required', 'string', 'max:2000']]);

        // The same reading a one to one message gets. A broadcast is still a
        // message, and it reaches more people. See MessageFilter.
        $read = app(\App\Services\MessageFilter::class)->inspect(trim($data['message_text']));

        if ($read['refusal'] !== null) {
            return $this->fail($read['refusal'], 422);
        }

        $text = $read['text'];

        $workerIds = $job->hires()->pluck('worker_id')->unique();

        if ($workerIds->isEmpty()) {
            return $this->fail('Nobody has been hired on this job yet.', 422);
        }

        $sent = 0;
        foreach ($workerIds as $workerId) {
            $conversation = Conversation::firstOrCreate(
                ['pair_low' => min($user->id, $workerId), 'pair_high' => max($user->id, $workerId)],
                ['job_id' => $job->id, 'employer_id' => $user->id, 'worker_id' => $workerId, 'status' => 'unlocked'],
            );
            $conversation->update(['status' => 'unlocked']);

            $message = $conversation->messages()->create([
                'sender_id'    => $user->id,
                'message_text' => $text,
                'is_read'      => false,
            ]);
            $conversation->touch();

            $message->setRelation('conversation', $conversation);
            $message->load(['sender:id,name,avatar', 'sender.workerProfile:id,user_id,profile_photo_path', 'sender.employerProfile:id,user_id,image_path']);

            app(RealtimeBroadcaster::class)->push(new ChatMessagePushed($message));
            MessageSent::dispatch($message);
            $sent++;
        }

        return $this->ok(['sent' => $sent], "Sent to {$sent} " . ($sent === 1 ? 'worker' : 'workers') . '.');
    }
}
