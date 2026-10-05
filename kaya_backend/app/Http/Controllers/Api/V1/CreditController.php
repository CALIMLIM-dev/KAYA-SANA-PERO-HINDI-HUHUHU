<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CreditPackage;
use App\Models\CreditTransaction;
use App\Services\CreditGrants;
use App\Services\CreditLedger;
use Illuminate\Http\Request;

/**
 * The wallet, its history, and what a top-up costs.
 *
 * Read only. Nothing here moves a balance — spending happens where the thing
 * being paid for happens, so a charge and the action it bought commit or fail
 * together.
 */
class CreditController extends Controller
{
    public function __construct(
        private CreditLedger $ledger,
        private CreditGrants $grants,
    ) {}

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    /**
     * Balance and prices in one call.
     *
     * The costs travel with the balance on purpose. The app has to show
     * "Apply · 2 credits" on a button before anyone taps it, and a client that
     * hard-codes the price will disagree with the server the day it changes.
     */
    /*
        A company whose documents have been approved.

        Both halves are required. Employer type alone would let anyone
        declare themselves a business and buy at the volume rate without ever
        proving they are one, which is the discount going to whoever reads the
        form most carefully rather than to actual volume.
    */
    private function isVerifiedBusiness($user): bool
    {
        if (! $user->isCompanyEmployer()) {
            return false;
        }

        $status = app(\App\Services\EmployerVerificationService::class)
            ->getEmployerVerification($user, $user->employerProfile()->first());

        return (bool) ($status['business_verified'] ?? false);
    }

    /*
        Free vs Top-up, as rows the app draws and never composes.

        Every figure is read from config here, so a price change moves the
        checklist with it - a 10 typed into the app that disagrees with
        CREDIT_COST_APPLY would be the next bug. Free gets the marketplace,
        top-up gets promotion; the first eight rows are the job flow and are
        the same on both sides on purpose.
    */
    private function comparison(): array
    {
        $grant = (int) config('kaya.credits.monthly_grant');
        $apply = (int) config('kaya.credits.apply');
        $invite = (int) config('kaya.credits.invite');
        $unlock = (int) config('kaya.credits.unlock');
        $freeDays = (int) config('kaya.jobs.free_days');
        $perBarya = (int) config('kaya.credits.post_days_per_barya');
        $boost = (int) config('kaya.credits.boost');
        $boostDays = (int) config('kaya.credits.boost_days');

        $row = fn (string $label, bool $free) => [
            'label' => $label, 'free' => $free, 'topped_up' => true,
        ];

        return [
            $row("{$grant} free barya every month", true),
            $row('Browse jobs and workers', true),
            $row("Post a job, first {$freeDays} days free", true),
            $row('Receive applications', true),
            $row(sprintf('Apply to a job (%d barya, about %d a month on free barya)', $apply, intdiv($grant, max(1, $apply))), true),
            $row("Invite a worker ({$invite} barya)", true),
            $row("Unlock a contact ({$unlock} barya)", true),
            $row('Chat, schedule, complete and review a hire', true),
            $row("Keep a job post up past {$freeDays} days (1 barya per {$perBarya} days)", false),
            $row("Boost a job or profile to the top ({$boost} barya, {$boostDays} days)", false),
            $row('More than 1 community board post at once (up to 3)', false),
            $row('Your full profile shown to employers when you apply', false),
        ];
    }

    public function wallet(Request $request)
    {
        $user = $request->user();
        $wallet = $this->ledger->walletFor($user);

        return $this->ok([
            // Integer, never a decimal string. See the note in CreditWallet.
            'balance' => (int) $wallet->balance,
            'costs' => [
                'apply'  => (int) config('kaya.credits.apply'),
                'invite' => (int) config('kaya.credits.invite'),
                'unlock' => (int) config('kaya.credits.unlock'),
                // A post's price is by its span, and the app has to show it
                // while the dates are being picked - so it gets the rule,
                // not a number. JobDurationService::costForSpan is the same
                // arithmetic on the server side.
                'boost'      => (int) config('kaya.credits.boost'),
                'boost_days' => (int) config('kaya.credits.boost_days'),
                'post_free_days'      => (int) config('kaya.jobs.free_days'),
                'post_days_per_barya' => (int) config('kaya.credits.post_days_per_barya'),
            ],
            'monthly_grant' => (int) config('kaya.credits.monthly_grant'),

            // Any top-up, ever. What the Top-up column of the checklist means.
            'has_topped_up' => $user->hasToppedUp(),
            'comparison'    => $this->comparison(),
            /*
                What is sitting there waiting to be collected.

                Sent with the balance so the wallet can show the button without
                a second request, and so the home screen can badge it — the
                whole point of claiming is that somebody notices.
            */
            'claimable' => $this->grants->available($user),
            /*
                Why the claim button is disabled, when it is.

                Sent as a flag rather than left for the app to infer from
                is_verified, because the app should not be re-deriving a money
                rule the server owns - that is how the two drift apart. The
                amount above stays truthful either way: it is waiting, it is
                just not collectable yet.
            */
            'claim_requires_verification' => $this->grants->requiresVerification($user),
            /*
                Only the bundles this account can actually buy.

                A verified company sees the business tiers; everyone else sees
                what they see today. Listing a bundle somebody is not allowed
                to purchase would be a price tag on a button that refuses.
            */
            'packages' => CreditPackage::active()
                ->forAudience($this->isVerifiedBusiness($user))
                ->get()->map(fn (CreditPackage $p) => [
                'id' => $p->id,
                'name' => $p->name,
                'credits' => $p->credits,
                // Centavos for arithmetic, pesos for display. The client should
                // never divide by 100 itself and get a rounding argument.
                'amount_centavos' => $p->amount_centavos,
                'amount_php' => $p->amountPhp(),
            ]),
        ]);
    }

    /**
     * Collect whatever is owed.
     *
     * Answers with what was actually paid rather than what was available, so a
     * second tap that lost the race honestly reports nothing — the wallet then
     * says so instead of celebrating credits it did not receive.
     */
    public function claim(Request $request)
    {
        // Which gift. Required rather than defaulted, because collecting the
        // wrong one silently is worse than being asked.
        $data = $request->validate([
            'type' => ['required', 'in:welcome,monthly'],
        ]);

        $user = $request->user();
        $claimed = $this->grants->claim($user, $data['type']);

        return $this->ok([
            'claimed' => $claimed,
            'claimable' => $this->grants->available($user),
            'balance' => $this->ledger->balance($user),
        ], $claimed['total'] === 0
            ? 'Nothing to claim right now'
            : 'Claimed ' . $claimed['total']);
    }

    /**
     * Where the credits went.
     *
     * Paginated and newest first. Every row says what it was for and what the
     * balance became, so someone querying a charge can follow it themselves
     * rather than asking support to look.
     */
    public function transactions(Request $request)
    {
        $data = $request->validate([
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $rows = CreditTransaction::where('user_id', $request->user()->id)
            // id breaks the tie: several rows can share a second, and ordering
            // by time alone lets paginated entries repeat or vanish.
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate($data['per_page'] ?? 20);

        $rows->getCollection()->transform(fn (CreditTransaction $t) => [
            'id' => $t->id,
            'delta' => $t->delta,
            'balance_after' => $t->balance_after,
            'reason' => $t->reason,
            'is_refund' => $t->isRefund(),
            'note' => $t->note,
            'reference_type' => $t->reference_type,
            'reference_id' => $t->reference_id,
            'created_at' => $t->created_at,
        ]);

        return $this->ok($rows);
    }
}
