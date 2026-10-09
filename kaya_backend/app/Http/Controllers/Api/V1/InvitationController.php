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
/*
    Imported, which it was not - and the whole of "Ask for work again"
    failed on that alone.

    workAgain type-hints NotificationService to have it injected. Without
    this line PHP resolved the name against this file namespace, so the
    container was asked for App\Http\Controllers\Api\V1\NotificationService,
    which does not exist. Every tap was a 500 raised while resolving the
    method arguments, before a line of the body ran - which is why fixing
    a bad column inside the body changed nothing.
*/
use App\Services\NotificationService;
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
        if (! $job->isOpenForApplications()) return $this->fail('Job must be open to send invitations', 422);

        $request->validate(['worker_id' => ['required', 'exists:users,id']]);

        $worker = User::findOrFail($request->worker_id);
        // Hybrid accounts are both worker and employer, so self-invitation is reachable.
        if ($worker->id === $user->id) return $this->fail('You cannot invite yourself to your own job', 422);
        if (!$worker->isWorker()) return $this->fail('User is not a worker', 422);
        if ($worker->is_suspended) return $this->fail('Worker account is suspended', 422);

        // Too far to be worth the fare. See WorkingDistance.
        if ($why = app(\App\Services\WorkingDistance::class)->refusalFor($job, $worker, 'employer')) {
            return $this->fail($why, 422);
        }

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
    /*
        A past worker telling an employer they are free again.

        The "Ask for Work Again" button used to open the employer's profile.
        The label promises to ask somebody something, and opening a page is not
        asking - which is why it read as broken. It could not do better on its
        own: completing a job archives the pair's thread deliberately, so the
        worker has no way to message a past employer at all.

        So this is the ask. One notification, nothing reopened, and the
        employer answers it by inviting them - which is the path that
        unarchives the thread and charges the rehire rate.

        Only somebody who actually worked for them. Without that this is a
        cold-contact endpoint: any account could notify any employer, which is
        the kind of thing that turns into spam the week after it ships.

        Once a day per employer. A worker who taps it twice is being eager,
        not sending two pieces of news, and the second notification would
        teach the employer to ignore the first.
    */
    public function workAgain(Request $request, \App\Models\User $employer, NotificationService $notifications)
    {
        $user = $request->user();

        if (! $user->isWorker()) {
            return $this->fail('You need a worker profile to do that.', 403);
        }

        if ($employer->id === $user->id) {
            return $this->fail('That is your own account.', 422);
        }

        $workedBefore = \App\Models\Application::where('worker_id', $user->id)
            ->where('status', 'completed')
            ->whereHas('job', fn ($q) => $q->where('employer_id', $employer->id))
            ->exists();

        if (! $workedBefore) {
            return $this->fail('You can only do this for someone you have finished a job for.', 422);
        }

        /*
            Matched on the reference, not on an actor column.

            user_notifications has no actor_id - push() takes one only to skip
            notifying somebody about themselves, and never stores it - so
            asking for that column was a 500 on every tap. The reference is
            the worker, which is exactly who this needs to be unique per.
        */
        $alreadyAsked = \App\Models\UserNotification::where('user_id', $employer->id)
            ->where('type', \App\Models\UserNotification::WORK_AGAIN_REQUESTED)
            ->where('reference_type', 'user')
            ->where('reference_id', $user->id)
            ->where('created_at', '>=', now()->subDay())
            ->exists();

        if ($alreadyAsked) {
            return $this->ok(
                ['already_sent' => true],
                'You already told them today. They have it.',
            );
        }

        $notifications->workAgainRequested($user, $employer->id);

        return $this->ok(
            ['already_sent' => false],
            ($employer->name ?? 'They') . ' has been told you are available.',
        );
    }
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
            ->with(['job.category:id,name', 'employer:id,name,avatar,is_verified', 'employer.employerProfile'])
            ->latest()
            ->paginate(20);

        // The thread for each accepted invitation, so Message opens it
        // rather than the inbox. One query for the page.
        $employerIds = $invitations->getCollection()
            ->where('status', 'accepted')
            ->pluck('employer_id')
            ->unique();
        $threads = $employerIds->isEmpty()
            ? collect()
            : Conversation::query()
                ->whereNull('archived_at')
                ->where(fn ($q) => $q
                    ->where(fn ($p) => $p->whereIn('pair_low', $employerIds)->where('pair_high', $user->id))
                    ->orWhere(fn ($p) => $p->where('pair_low', $user->id)->whereIn('pair_high', $employerIds)))
                ->get(['id', 'pair_low', 'pair_high'])
                ->mapWithKeys(fn ($c) => [($c->pair_low === $user->id ? $c->pair_high : $c->pair_low) => $c->id]);

        /*
            An explicit shape, not the models.

            This sent the job and the employer's profile as stored, which
            carried the job's street address and coordinates and the
            employer's own pin to every worker invited - before they had
            accepted anything. The exact place is released on hire, the same
            rule as the feed (JobPost::forViewer).
        */
        $invitations->getCollection()->transform(function (Invitation $inv) use ($threads) {
            $job = $inv->job;
            $employer = $inv->employer;
            $profile = $employer?->employerProfile;
            $isCompany = $profile?->employer_type === \App\Enums\EmployerType::COMPANY;

            return [
                'id'              => $inv->id,
                'status'          => $inv->status,
                'created_at'      => $inv->created_at,
                'conversation_id' => $inv->status === 'accepted' ? ($threads[$inv->employer_id] ?? null) : null,
                'employer'        => $employer ? [
                    'id'          => $employer->id,
                    'name'        => $isCompany && filled($profile?->company_name) ? $profile->company_name : $employer->name,
                    'person_name' => $employer->name,
                    'is_company'  => $isCompany,
                    'avatar'      => $employer->avatar,
                    'is_verified' => (bool) $employer->is_verified,
                    'verification_state' => $employer->verification_state,
                    'rating'      => $profile?->rating_avg !== null ? (float) $profile->rating_avg : null,
                    'rating_count'=> (int) ($profile?->rating_count ?? 0),
                ] : null,
                'job'             => $job ? [
                    'id'             => $job->id,
                    'title'          => $job->title,
                    'description'    => $job->description,
                    'status'         => $job->status,
                    'is_open'        => $job->isOpenForApplications(),
                    'category'       => $job->category?->name,
                    'location'       => $job->location,
                    'city'           => $job->city,
                    'budget_min'     => $job->budget_min,
                    'budget_max'     => $job->budget_max,
                    'budget_period'  => $job->budget_period,
                    'start_date'     => $job->start_date?->format('Y-m-d'),
                    'end_date'       => $job->end_date?->format('Y-m-d'),
                    'start_time'     => $job->start_time,
                    'workers_needed' => (int) ($job->workers_needed ?? 1),
                ] : null,
            ];
        });

        return $this->ok($invitations);
    }

    public function accept(Request $request, Invitation $invitation)
    {
        $user = $request->user();
        if ($invitation->worker_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($invitation->status !== 'pending') return $this->fail('Invitation status must be pending to accept', 422);

        /*
            An applicant an employer can actually read.

            A profile row exists from the moment setup starts, so an abandoned
            attempt is a profile with no trade and no skills. Applying with one
            puts a card in front of an employer that says nothing about the
            person behind it, and the employer has no way to ask - they are
            choosing between named trades.

            isSetupCompleted is the same three facts browse() filters on, so
            this refuses exactly the profiles that are already absent from the
            worker directory. Nothing that can be found is blocked here.

            Refused on the server because the app can be out of date, and this
            is what an employer is shown.
        */
        $workerProfile = $user->workerProfile;

        if ($workerProfile === null || ! $workerProfile->isSetupCompleted()) {
            return $this->fail(
                'Add your trade and at least one skill to your worker profile first.',
                422
            );
        }

        $job = $invitation->job;
        if (!$job || ! $job->isOpenForApplications()) return $this->fail('Job is no longer available', 422);

        /*
            A worker with other work can still take this.

            The mirror of the guard removed from accepting an applicant,
            and gone for the same reason: how much work somebody can carry
            on a given day is theirs to answer, not the app's. They are
            shown what they already hold and decide.
        */

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
            'archived_at' => null,
        ]);

        app(\App\Services\ChatEvents::class)->hired($conversation, $job, $job->employer, $user);

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
