<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Models\Verification;
use App\Services\NotificationService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Approves an account's verification from the command line.
 *
 * The admin panel is the normal way to do this and stays the normal way. This
 * exists because verification now gates every action worth demonstrating -
 * posting, applying, inviting, boosting, accepting an invitation, claiming and
 * topping up - and the only way through that gate was a human sitting in
 * /admin. An account created while nobody is watching the queue can browse and
 * do nothing else, which during a demo looks exactly like a broken app rather
 * than like a working access rule.
 *
 * Marks the same state the admin panel's approve button marks, so an account
 * verified this way is indistinguishable from one approved by hand: the
 * pending Verification rows move to 'verified', is_verified goes true, and the
 * same notification is sent. Anything less would leave an account that is
 * verified for the middleware and still pending in the admin list.
 *
 *     php artisan kaya:verify someone@example.com
 *     php artisan kaya:verify someone@example.com --business
 */
class VerifyAccount extends Command
{
    protected $signature = 'kaya:verify
        {email : The account to verify}
        {--business : Also approve business documents, for a company employer}';

    protected $description = 'Approve an account\'s verification without the admin panel';

    public function handle(NotificationService $notifications): int
    {
        $email = trim($this->argument('email'));
        $user = User::where('email', $email)->first();

        if (! $user) {
            $this->error("No account with the email {$email}.");

            return self::FAILURE;
        }

        if ($user->is_verified && ! $this->option('business')) {
            // Nothing to change: identity is the only thing this would set.
            $this->info("{$user->name} is already verified. Nothing to do.");

            return self::SUCCESS;
        }

        $business = (bool) $this->option('business');

        DB::transaction(function () use ($user, $business) {
            /*
                Approve what is actually pending, and invent nothing.

                A submitted document that stays 'pending' while the account
                reads as verified is the drift this command exists to avoid -
                the admin queue would keep showing work that is already done.
                An account with no documents at all is still verified, because
                the point here is to unblock a demo account, and refusing on
                the grounds that it never uploaded anything would defeat that.
            */
            Verification::where('user_id', $user->id)
                ->where('status', 'pending')
                ->update([
                    'status'      => 'verified',
                    'reviewed_at' => now(),
                ]);

            /*
                A company needs an approved 'business_reg' row specifically.

                EnsureVerified asks EmployerVerificationService, and that reads
                business_verified from a verification of exactly that document
                type - not from is_verified, and not from whatever else the
                account happens to have approved. Approving only what was
                pending would leave a company employer still refused at
                POST /jobs with no obvious reason, so the row is created when
                it is not there.
            */
            if ($business) {
                Verification::updateOrCreate(
                    ['user_id' => $user->id, 'document_type' => 'business_reg'],
                    ['status' => 'verified', 'reviewed_at' => now()],
                );
            }

            // forceFill: is_verified is intentionally not mass-assignable.
            $user->forceFill(['is_verified' => true])->save();
        });

        $notifications->verificationApproved(
            userId: $user->id,
            audience: $business ? 'employer' : 'worker',
        );

        $this->info("{$user->name} ({$user->email}) is verified.");

        if ($this->option('business')) {
            $this->line('Business documents approved too.');
        }

        return self::SUCCESS;
    }
}
