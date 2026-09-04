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
use App\Models\CreditTransaction;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Database\UniqueConstraintViolationException;
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

        /*
            Matched against the whole key, not a subset of statuses.

            invitations carries a unique index on (job_id, employer_id,
            worker_id) with no status in it, while this check only looked at
            pending and accepted. A worker who declined therefore passed the
            guard and hit the constraint, so re-inviting them answered 500 with
            a raw SQL error — a live crash on an ordinary action.

            The guard now covers exactly what the index covers, and says which
            of the three cases it is, because "already invited" and "they said
            no" call for very different things from the employer.
        */
        /*
            They already applied - there is nothing to invite them to.

            Nothing checked this, so an employer could pay two barya to invite
            somebody who was already sitting in their applicant list waiting
            for a yes. That is money for an introduction that had already been
            made, from the other direction, and it left the job holding a
            pending application and a pending invitation between the same two
            people with no way to tell which one mattered.

            Refused rather than silently charged, and worded so the employer
            knows the thing they wanted is one tap away in the applicants
            list.
        */
        $application = \App\Models\Application::where('job_id', $job->id)
            ->where('worker_id', $worker->id)
            ->whereNotIn('status', ['withdrawn', 'rejected'])
            ->first();

        if ($application !== null) {
            return $this->fail(
                $application->status === 'pending'
                    ? $worker->name . ' has already applied to this job. Accept them from your applicants instead.'
                    : $worker->name . ' is already on this job.',
                422
            );
        }

        $existing = Invitation::where('job_id', $job->id)
            ->where('employer_id', $user->id)
            ->where('worker_id', $worker->id)
            ->first();

        if ($existing) {
            return $this->fail(match ($existing->status) {
                'accepted' => $worker->name . ' has already accepted an invitation to this job',
                'declined' => $worker->name . ' declined an invitation to this job',
                default    => 'Invitation already sent to this worker',
            }, 422);
        }

        /*
            A proven pairing costs less to repeat.

            Both the price and the reason come from RehireService, which is
            also what the applicant card's "Hired 3x" badge counts. One source
            for the fact, because an employer told "Hired before" and charged
            full price is a bug report, and charged half with no badge showing
            is a mystery discount.
        */
        $rehire = app(\App\Services\RehireService::class);

        try {
            $invitation = app(CreditLedger::class)->charge(
                user: $user,
                amount: $rehire->inviteCost($user, $worker),
                reason: $rehire->inviteReason($user, $worker),
                referenceType: 'job',
                referenceId: $job->id,
                using: fn (CreditTransaction $charge) => Invitation::create([
                    'job_id'      => $job->id,
                    'employer_id' => $user->id,
                    'worker_id'   => $worker->id,
                    'status'      => 'pending',
                    'credit_transaction_id' => $charge->id,
                ]),
            );
        } catch (UniqueConstraintViolationException) {
            /*
                The check above and this insert are two statements, so two
                taps close together can both pass the read and race here. The
                database refuses the second, and the friendly answer is the
                same one it would have been a moment earlier.
            */
            return $this->fail('Invitation already sent to this worker', 422);
        }

        InvitationSent::dispatch($invitation->load(['job', 'employer']));

        return $this->ok($invitation, 'Invitation sent successfully', 201);
    }

    /**
     * Everyone this employer has finished a job with.
     *
     * Derived from completed applications - the completed application is the
     * record of having worked together, so there is nothing to store. Each
     * row carries what it costs to invite that person again, because the
     * discount is the whole point of the screen and a price the app has to
     * work out for itself is a price the two sides can disagree about.
     */
    public function pastWorkers(Request $request)
    {
        $user = $request->user();

        if (! $user->isEmployer()) {
            return $this->fail('Forbidden', 403);
        }

        $rehire = app(\App\Services\RehireService::class);

        return $this->ok([
            'workers'      => $rehire->pastWorkers($user),
            // Flat, because every worker on this list is by definition a
            // rehire. Sent anyway so the app never hardcodes the number.
            'invite_cost'  => (int) config('kaya.credits.rehire_invite'),
            'normal_cost'  => (int) config('kaya.credits.invite'),
        ]);
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

        /*
            The job starts, same as accepting an application.

            Accepting an invitation is a hire - the employer offered, the
            worker took it - so the job moves to in_progress, exactly as it does
            when an employer accepts an application. Without this the job stayed
            open, and location sharing refused to start ("only while the job is
            in progress"), so the tracker never appeared for a worker who came
            in through an invitation while it worked for one who applied.
        */
        if ($job->status === 'open') {
            $job->update(['status' => 'in_progress']);
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
