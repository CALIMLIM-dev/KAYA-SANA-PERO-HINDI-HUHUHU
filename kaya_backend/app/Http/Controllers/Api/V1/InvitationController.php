<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\InvitationAccepted;
use App\Events\InvitationDeclined;
use App\Events\InvitationSent;
use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\Conversation;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Http\Request;

class InvitationController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function send(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($job->status !== 'open') return $this->fail('Job must be open to send invitations', 422);

        $request->validate(['worker_id' => ['required', 'exists:users,id']]);

        $worker = User::findOrFail($request->worker_id);
        // Hybrid accounts are both worker and employer, so self-invitation is reachable.
        if ($worker->id === $user->id) return $this->fail('You cannot invite yourself to your own job', 422);
        if (!$worker->isWorker()) return $this->fail('User is not a worker', 422);
        if ($worker->is_suspended) return $this->fail('Worker account is suspended', 422);

        $existing = Invitation::where('job_id', $job->id)
            ->where('worker_id', $worker->id)
            ->whereIn('status', ['pending', 'accepted'])
            ->first();

        if ($existing) return $this->fail('Invitation already sent to this worker', 422);

        $invitation = Invitation::create([
            'job_id'      => $job->id,
            'employer_id' => $user->id,
            'worker_id'   => $worker->id,
            'status'      => 'pending',
        ]);

        InvitationSent::dispatch($invitation->load(['job', 'employer']));

        return $this->ok($invitation, 'Invitation sent successfully', 201);
    }

    public function myInvitations(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $invitations = $user->invitationsReceived()
            ->with(['job.employer:id,name,avatar,is_verified', 'job.employer.employerProfile', 'employer:id,name,avatar,is_verified'])
            ->latest()
            ->paginate(20);

        return $this->ok($invitations);
    }

    public function accept(Request $request, Invitation $invitation)
    {
        $user = $request->user();
        if ($invitation->worker_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($invitation->status !== 'pending') return $this->fail('Invitation status must be pending to accept', 422);

        $job = $invitation->job;
        if (!$job || $job->status !== 'open') return $this->fail('Job is no longer available', 422);

        /*
            Same double-booking guard as accepting an applicant, from the other
            side of the handshake. Accepting an invitation creates an accepted
            application, so without this a worker could take an invite for a day
            they have already promised to somebody else.

            Worded for the worker, who -- unlike the employer -- is entitled to
            know it is their own prior job in the way.
        */
        $schedule = app(\App\Services\ScheduleConflictService::class);
        $commitment = $schedule->existingCommitment($user->id, $job);

        if ($commitment !== null) {
            return $this->fail($schedule->clashMessage($commitment, addressingWorker: true), 422);
        }

        $invitation->update(['status' => 'accepted']);

        // Create or update application
        $application = Application::firstOrCreate(
            ['job_id' => $job->id, 'worker_id' => $user->id],
            ['status' => 'accepted']
        );

        if (in_array($application->status, ['pending', 'withdrawn'])) {
            $application->update(['status' => 'accepted']);
        }

        // Unlock or create conversation
        // One thread per person — see the matching block in ApplicationController.
        $conversation = Conversation::firstOrCreate(
            [
                'pair_low' => min($invitation->employer_id, $user->id),
                'pair_high' => max($invitation->employer_id, $user->id),
            ],
            [
                'job_id' => $job->id,
                'employer_id' => $invitation->employer_id,
                'worker_id' => $user->id,
                'status' => 'unlocked',
            ]
        );

        $conversation->update([
            'status' => 'unlocked',
            'job_id' => $job->id,
            'employer_id' => $invitation->employer_id,
            'worker_id' => $user->id,
        ]);

        InvitationAccepted::dispatch($invitation->load(['job', 'worker']));

        return $this->ok([
            'invitation'      => $invitation,
            'application_id'  => $application->id,
            'conversation_id' => $conversation->id,
        ], 'Invitation accepted successfully');
    }

    public function decline(Request $request, Invitation $invitation)
    {
        $user = $request->user();
        if ($invitation->worker_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($invitation->status !== 'pending') return $this->fail('Invitation status must be pending to decline', 422);

        $invitation->update(['status' => 'declined']);

        InvitationDeclined::dispatch($invitation->load(['job', 'worker']));

        return $this->ok($invitation, 'Invitation declined successfully');
    }
}
