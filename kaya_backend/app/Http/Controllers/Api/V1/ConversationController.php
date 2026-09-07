<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\MessageSent;
use App\Events\Realtime\ChatMessagePushed;
use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ScheduleProposal;
use App\Models\User;
use App\Services\RealtimeBroadcaster;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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
            'worker:id,name,avatar,is_verified,last_seen_at',
            /*
                So the inbox can show a face.

                users.avatar is only the Google photo, and anybody who signed
                up with an email put their picture on a profile instead - so
                every row in the inbox and every chat header drew a letter.
                Eager-loaded rather than resolved per row, which would be a
                query per conversation.
            */
            'employer.workerProfile:id,user_id,profile_photo_path',
            'employer.employerProfile:id,user_id,image_path',
            'worker.workerProfile:id,user_id,profile_photo_path',
            'worker.employerProfile:id,user_id,image_path',
            'latestMessage'])
            ->withCount(['messages as unread_count' => fn ($q) => $q->where('is_read', false)->where('sender_id', '!=', $user->id)])
            ->orderByDesc('updated_at')
            ->paginate(20);

        $this->attachApplications($conversations->getCollection());

        /*
            The resolved picture for both sides of every thread.

            Written onto the loaded user rather than into a new key, so the
            app keeps reading `avatar` and nothing on the client has to learn
            a second field name.
        */
        $conversations->getCollection()->each(function ($c) {
            $c->employer?->setAttribute('avatar', $c->employer->resolvedAvatarUrl());
            $c->worker?->setAttribute('avatar', $c->worker->resolvedAvatarUrl());
        });

        return $this->ok($conversations);
    }

    /**
     * Attaches each conversation's hire (application_id + status).
     *
     * A hire is identified by job_id AND worker_id together, which an Eloquent
     * relation can't express cleanly under eager loading. Done as one extra
     * query for the whole page rather than one per row.
     */
    /*
        Every bubble's sender picture, resolved.

        The avatar column alone is the Google photo, and most accounts here
        signed up with an email - so a group of messages showed a column of
        letters. Written back onto `avatar` so the app keeps reading one key.
    */
    private function resolveSenderAvatars($messages): void
    {
        $messages->each(function ($m) {
            $m->sender?->setAttribute('avatar', $m->sender->resolvedAvatarUrl());
        });
    }

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

        /*
            Incremental fetch, for polling.

            `?after_id=N` returns only messages newer than N, oldest first, and
            nothing else. The client polls this every few seconds while a chat
            is open, so the overwhelmingly common answer is an empty array —
            which is the point. Re-sending a fifty-message thread every three
            seconds to discover nothing changed is unusable on a slow
            connection, and it is exactly what a poll would otherwise do.

            Not paginated, because a delta is not a page: the client already
            holds everything up to N, and wrapping the handful of new rows in
            pagination metadata would invite the client to treat "no new
            messages" as "end of thread" and stop asking.

            Capped anyway. A client returning after a long absence with a very
            old cursor should get a bounded response rather than the entire
            history in one go; it can simply ask again with the new highest id.
        */
        if ($request->filled('after_id')) {
            $messages = $conversation->messages()
                ->with(['sender:id,name,avatar', 'sender.workerProfile:id,user_id,profile_photo_path', 'sender.employerProfile:id,user_id,image_path'])
                ->where('id', '>', (int) $request->input('after_id'))
                ->orderBy('id')
                ->limit(100)
                ->get();

            $this->resolveSenderAvatars($messages);

            return $this->ok(['data' => $messages]);
        }

        $messages = $conversation->messages()
            ->with(['sender:id,name,avatar', 'sender.workerProfile:id,user_id,profile_photo_path', 'sender.employerProfile:id,user_id,image_path'])
            ->orderBy('created_at')
            ->paginate(50);

        $this->resolveSenderAvatars($messages->getCollection());

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
        $message->load(['sender:id,name,avatar', 'sender.workerProfile:id,user_id,profile_photo_path', 'sender.employerProfile:id,user_id,image_path']);

        // Straight to both devices on the thread, then the notification row for
        // whoever isn't looking at it.
        app(RealtimeBroadcaster::class)->push(new ChatMessagePushed($message));

        MessageSent::dispatch($message);

        return $this->ok($message, 'Message sent successfully', 201);
    }

    /*
        POST /conversations/{conversation}/schedule

        Offers a day and a part of it for the work. Either side can send one:
        a worker saying "I can come Saturday morning" and an employer asking
        the same thing are one message, and building only the employer's half
        would make the worker somebody things are arranged around rather than
        with.

        The offer also lands in the thread as an ordinary message, so the
        conversation still reads as a conversation - somebody scrolling back a
        week sees where the Saturday was agreed rather than a gap.
    */
    public function proposeSchedule(Request $request, Conversation $conversation)
    {
        $user = $request->user();

        if ($conversation->employer_id !== $user->id && $conversation->worker_id !== $user->id) {
            return $this->fail('You are not part of this conversation', 403);
        }

        if ($conversation->status === 'locked') {
            return $this->fail('Scheduling unlocks once the application is accepted', 403);
        }

        $data = $request->validate([
            'scheduled_date' => ['required', 'date', 'after_or_equal:today'],
            // H:i, the only shape the column takes. A part of the day was
            // the vocabulary of a weekly pattern; two people settling one
            // job say an hour.
            'scheduled_time' => ['required', 'date_format:H:i'],
            'note'           => ['nullable', 'string', 'max:280'],
            'job_id'         => ['nullable', 'integer', 'exists:jobs_posts,id'],
        ], [
            'scheduled_date.after_or_equal' => 'Pick a day that has not passed.',
        ]);

        $proposal = DB::transaction(function () use ($conversation, $user, $data) {
            /*
                One live offer per thread.

                Two open proposals is two people accepting different days and
                both believing it is settled. An earlier one is superseded
                rather than deleted, so the thread keeps its history.
            */
            ScheduleProposal::where('conversation_id', $conversation->id)
                ->where('status', 'proposed')
                ->update(['status' => 'superseded', 'responded_at' => now()]);

            return ScheduleProposal::create([
                'conversation_id' => $conversation->id,
                'job_id'          => $data['job_id'] ?? $conversation->job_id,
                'proposed_by'     => $user->id,
                'scheduled_date'  => $data['scheduled_date'],
                'scheduled_time'  => $data['scheduled_time'],
                'note'            => $data['note'] ?? null,
                'status'          => 'proposed',
            ]);
        });

        return $this->ok($this->presentProposal($proposal), 'Schedule proposed', 201);
    }

    /*
        POST /conversations/{conversation}/schedule/{proposal}/respond

        Accept or decline. Only the other side may answer - proposing and
        accepting your own offer would make agreement meaningless - and only
        while it is still the live one.
    */
    public function respondToSchedule(
        Request $request,
        Conversation $conversation,
        ScheduleProposal $proposal,
    ) {
        $user = $request->user();

        if ($conversation->employer_id !== $user->id && $conversation->worker_id !== $user->id) {
            return $this->fail('You are not part of this conversation', 403);
        }

        if ($proposal->conversation_id !== $conversation->id) {
            return $this->fail('That proposal is not on this conversation', 404);
        }

        if ($proposal->proposed_by === $user->id) {
            return $this->fail('The other person has to answer this one.', 422);
        }

        if ($proposal->status !== 'proposed') {
            return $this->fail('That proposal has already been answered.', 422);
        }

        $data = $request->validate([
            'accept' => ['required', 'boolean'],
        ]);

        $accepted = (bool) $data['accept'];

        $proposal->update([
            'status'       => $accepted ? 'accepted' : 'declined',
            'responded_at' => now(),
        ]);

        return $this->ok(
            $this->presentProposal($proposal->fresh()),
            $accepted ? 'Schedule agreed' : 'Schedule declined',
        );
    }

    /*
        GET /conversations/{conversation}/schedule

        What the two of them have settled, and anything still waiting on an
        answer. The screen needs both: an agreed day to show at the top, and a
        live offer to put buttons under.
    */
    public function schedule(Request $request, Conversation $conversation)
    {
        $user = $request->user();

        if ($conversation->employer_id !== $user->id && $conversation->worker_id !== $user->id) {
            return $this->fail('You are not part of this conversation', 403);
        }

        $live = ScheduleProposal::where('conversation_id', $conversation->id)
            ->live()
            ->latest()
            ->first();

        $agreed = ScheduleProposal::where('conversation_id', $conversation->id)
            ->where('status', 'accepted')
            ->latest('responded_at')
            ->first();

        /*
            Every day this worker has already agreed to, across all their
            threads.

            Sent so the employer can SEE it while choosing a day - the picker
            marks those days and the sheet says so plainly - rather than being
            refused after the fact. Somebody may well want that Saturday
            anyway: work gets moved, mornings get swapped, and the two people
            in the conversation know things the server does not. What is not
            acceptable is booking somebody who is taken without ever being
            told.

            Dates only, by the day. Which job, which employer and where are
            another conversation's business.
        */
        $busy = ScheduleProposal::commitmentsFor(
            $conversation->worker_id,
            exceptConversation: $conversation->id,
        );

        return $this->ok([
            'pending' => $live ? $this->presentProposal($live) : null,
            'agreed'  => $agreed ? $this->presentProposal($agreed) : null,
            'worker_busy' => $busy,
        ]);
    }

    private function presentProposal(ScheduleProposal $proposal): array
    {
        return [
            'id'             => $proposal->id,
            'job_id'         => $proposal->job_id,
            'proposed_by'    => $proposal->proposed_by,
            'scheduled_date' => $proposal->scheduled_date->toDateString(),
            'scheduled_time' => $proposal->timeLabel(),
            'note'           => $proposal->note,
            'status'         => $proposal->status,
            // Written by the model so every surface says the same date the
            // same way.
            'summary'        => $proposal->summary(),
            'responded_at'   => $proposal->responded_at?->toIso8601String(),
        ];
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
