<?php

namespace App\Services;

use App\Models\Application;
use App\Models\CommunityPost;
use App\Models\CreditTransaction;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\Verification;
use App\Models\WorkerCertification;
use App\Models\WorkerExperience;
use App\Models\WorkerLicense;
use App\Models\WorkerLicenseExamination;
use App\Models\WorkerSkill;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/*
    Deleting an account, the way the Data Privacy Act means it.

    Everything that identifies the person goes: name, email, phone, photos,
    the identity documents, the resume, both profiles and what hangs off
    them, the notifications, the saved jobs. Anything still pending on their
    side is closed and, where somebody else paid for it, refunded.

    The row itself stays, blank. Credit transactions, the reviews other
    people were given, reports, and the admin's audit log all point at this
    id and have to keep adding up after the person is gone. A chat the
    other side still has shows "Deleted account" where the name was.

    Refused while work is in progress. A hire that is under way has two
    people relying on it, and deleting one of them mid-job takes the other
    one's chat, tracking and completion with it.
*/
class AccountDeletionService
{
    public function __construct(private CreditLedger $ledger) {}

    /** Why the account cannot be deleted right now, or null when it can. */
    public function blocker(User $user): ?string
    {
        $hiring = $user->postedJobs()->where('status', 'in_progress')->count();
        if ($hiring > 0) {
            return 'You have ' . $hiring . ' job' . ($hiring === 1 ? '' : 's')
                . ' with a worker on it. Finish or cancel ' . ($hiring === 1 ? 'it' : 'them') . ' first.';
        }

        $working = Application::where('worker_id', $user->id)
            ->where('status', 'accepted')
            ->whereHas('job', fn ($q) => $q->where('status', 'in_progress'))
            ->count();
        if ($working > 0) {
            return 'You are hired on ' . $working . ' job' . ($working === 1 ? '' : 's')
                . ' that is not finished. Finish ' . ($working === 1 ? 'it' : 'them') . ' first.';
        }

        return null;
    }

    public function delete(User $user): void
    {
        DB::transaction(function () use ($user) {
            $this->closePostedJobs($user);
            $this->withdrawApplications($user);
            $this->endInvitations($user);
            $this->endCommunityPosts($user);
            $this->removeDocuments($user);
            $this->removeProfiles($user);

            UserNotification::where('user_id', $user->id)->delete();
            DB::table('saved_jobs')->where('worker_id', $user->id)->delete();
            $user->tokens()->delete();

            $user->forceFill([
                'name'            => 'Deleted account',
                'first_name'      => 'Deleted',
                'middle_name'     => null,
                'last_name'       => 'account',
                'suffix'          => null,
                'email'           => 'deleted-' . $user->id . '@deleted.kaya',
                'phone'           => null,
                'city'            => null,
                'avatar'          => null,
                'profile_picture' => null,
                'google_id'       => null,
                'password'        => Hash::make(Str::random(40)),
                'deleted_at'      => now(),
            ])->save();
        });
    }

    /** Open posts close; the people waiting on them get their credits back. */
    private function closePostedJobs(User $user): void
    {
        $jobs = $user->postedJobs()->where('status', JobPost::STATUS_OPEN)->get();

        foreach ($jobs as $job) {
            $charges = CreditTransaction::whereIn(
                'id',
                Application::where('job_id', $job->id)
                    ->where('status', 'pending')
                    ->pluck('credit_transaction_id')
                    ->filter()
                    ->all(),
            )->get();

            foreach ($charges as $charge) {
                $this->ledger->refund($charge, 'the employer deleted their account');
            }

            Application::where('job_id', $job->id)->where('status', 'pending')
                ->update(['status' => 'rejected']);
            Invitation::where('job_id', $job->id)->where('status', 'pending')
                ->update(['status' => 'declined']);

            $job->update(['status' => 'closed']);
        }
    }

    /** Their own pending applications are withdrawn, not refunded: they chose to apply. */
    private function withdrawApplications(User $user): void
    {
        Application::where('worker_id', $user->id)
            ->where('status', 'pending')
            ->update(['status' => 'withdrawn']);
    }

    private function endInvitations(User $user): void
    {
        Invitation::where('worker_id', $user->id)->where('status', 'pending')
            ->update(['status' => 'declined']);
        Invitation::where('employer_id', $user->id)->where('status', 'pending')
            ->update(['status' => 'declined']);
    }

    private function endCommunityPosts(User $user): void
    {
        $posts = CommunityPost::where('user_id', $user->id)->get();
        foreach ($posts as $post) {
            $this->forget(config('filesystems.media'), $post->photo_path);
            $post->update(['status' => CommunityPost::STATUS_ENDED, 'photo_path' => null]);
        }
    }

    /** Identity documents and selfies: files and rows both. */
    private function removeDocuments(User $user): void
    {
        foreach (Verification::where('user_id', $user->id)->get() as $doc) {
            $this->forget(config('filesystems.documents'), $doc->document_front_url);
            $this->forget(config('filesystems.documents'), $doc->document_back_url);
            $this->forget(config('filesystems.documents'), $doc->selfie_url);
            $doc->delete();
        }
    }

    private function removeProfiles(User $user): void
    {
        $this->forget(config('filesystems.media'), $user->avatar);
        $this->forget(config('filesystems.media'), $user->profile_picture);

        if ($worker = $user->workerProfile) {
            $this->forget(config('filesystems.media'), $worker->profile_photo_path);
            $this->forget(config('filesystems.documents'), $worker->resume_path);

            foreach (WorkerCertification::where('user_id', $user->id)->get() as $row) {
                $this->forget(config('filesystems.media'), $row->document_path ?? null);
                $row->delete();
            }
            foreach (WorkerLicense::where('user_id', $user->id)->get() as $row) {
                $this->forget(config('filesystems.media'), $row->document_path ?? null);
                $row->delete();
            }
            WorkerLicenseExamination::where('user_id', $user->id)->delete();
            WorkerSkill::where('user_id', $user->id)->delete();
            WorkerExperience::where('user_id', $user->id)->delete();

            $worker->delete();
        }

        if ($employer = $user->employerProfile) {
            $this->forget(config('filesystems.media'), $employer->image_path);
            $this->forget(config('filesystems.media'), $employer->logo_path ?? null);
            $employer->delete();
        }
    }

    /** Best effort. A file already gone must not stop the deletion. */
    private function forget(?string $disk, ?string $path): void
    {
        if (! $disk || ! $path || str_starts_with($path, 'http')) {
            return;
        }

        try {
            Storage::disk($disk)->delete($path);
        } catch (\Throwable) {
            // Storage on the server is owned by another user. The row goes
            // regardless; the file is orphaned, not served.
        }
    }
}
