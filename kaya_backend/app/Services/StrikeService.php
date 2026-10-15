<?php

namespace App\Services;

use App\Models\Report;
use App\Models\Strike;
use App\Models\User;
use App\Support\ModerationReasons;
use Illuminate\Support\Facades\DB;

/*
    Strikes: what an upheld finding does to an account, and how it is undone.

    The same finding used to cost somebody nothing or everything depending
    on which administrator read it. Now it climbs a published ladder
    (config/moderation.php): a warning, a short restriction, a week's
    suspension, a month's, then a ban. Strikes expire, so one bad month
    does not follow somebody for good. Scam, fake papers and threats skip
    the ladder, and a ban is never one person's decision - it holds as a
    long suspension until a second administrator confirms it.

    Every strike sends a statement of reasons, and every strike can be
    appealed once, to an administrator who did not issue it.
*/
class StrikeService
{
    public function __construct(
        private SuspensionService $suspensions,
        private NotificationService $notify,
    ) {}

    /** What the next strike for this rule would do to this account. */
    public function nextStep(User $user, string $reasonCode): array
    {
        $number = $user->strikes()->active()->count() + 1;

        if (ModerationReasons::isCritical($reasonCode)) {
            return ['action' => 'ban', 'days' => null, 'number' => $number];
        }

        $ladder = config('moderation.ladder');

        return $ladder[min($number, max(array_keys($ladder)))] + ['number' => $number];
    }

    /**
     * @param  string|null  $duration  From the user page: days, or 'permanent'. Skips the ladder.
     */
    public function issue(User $user, string $reasonCode, string $finding, User $admin, ?Report $report = null, ?string $duration = null): Strike
    {
        $step = match (true) {
            $duration === null        => $this->nextStep($user, $reasonCode),
            $duration === 'permanent' => ['action' => 'ban', 'days' => null],
            default                   => ['action' => 'suspension', 'days' => (int) $duration],
        };

        $strike = DB::transaction(function () use ($user, $reasonCode, $finding, $admin, $report, $step) {
            $ban = $step['action'] === 'ban';

            // A ban is permanent at once: one admin decides, as with
            // everything else on the panel.
            $strike = Strike::create([
                'user_id'      => $user->id,
                'report_id'    => $report?->id,
                'reason_code'  => $reasonCode,
                'action'       => $step['action'],
                'days'         => $step['days'],
                'finding'      => $finding,
                'issued_by'    => $admin->id,
                'ends_at'      => $step['days'] ? now()->addDays($step['days']) : null,
                'expires_at'   => now()->addDays((int) config('moderation.strike_days')),
                'confirmed_by' => $ban ? $admin->id : null,
                'confirmed_at' => $ban ? now() : null,
            ]);

            if ($step['action'] === 'suspension') {
                $this->suspensions->suspend($user, $reasonCode, (string) $step['days'], $finding, $admin);
            }
            if ($ban) {
                $this->suspensions->suspend($user, $reasonCode, 'permanent', $finding, $admin);
                $this->banIdentities($strike);
            }

            return $strike;
        });

        $this->notify->strikeIssued($strike);

        return $strike;
    }

    /*
        An admin takes an offense back, without waiting for an appeal: it
        stops counting and whatever it limited is lifted.
    */
    public function remove(Strike $strike): ?string
    {
        if ($strike->removed_at !== null) {
            return 'This offense was already removed.';
        }

        DB::transaction(function () use ($strike) {
            $strike->update(['removed_at' => now()]);
            DB::table('banned_identities')->where('strike_id', $strike->id)->delete();
            $this->restoreStanding($strike->user);
        });

        $this->notify->offenseRemoved($strike->fresh());

        return null;
    }

    /*
        Lifts a suspension or ban early. The offenses stay on record and
        keep counting; only what holds the account ends now.
    */
    public function liftSuspension(User $user): void
    {
        DB::transaction(function () use ($user) {
            $user->strikes()->whereNull('removed_at')->where('action', 'suspension')
                ->where('ends_at', '>', now())->update(['ends_at' => now()]);
            $bans = $user->strikes()->whereNull('removed_at')->where('action', 'ban')->pluck('id');
            $user->strikes()->whereIn('id', $bans)->update(['removed_at' => now()]);
            DB::table('banned_identities')->whereIn('strike_id', $bans)->delete();

            $this->suspensions->reinstate($user);
        });

        $this->notify->suspensionLifted($user);
    }

    public function appeal(Strike $strike, string $text): void
    {
        $strike->update(['appeal' => $text, 'appealed_at' => now(), 'appeal_status' => 'pending']);
    }

    /** Returns an error, or null. */
    public function decideAppeal(Strike $strike, User $admin, bool $overturn, string $note): ?string
    {
        if ($strike->appeal_status !== 'pending') {
            return 'This request has already been decided.';
        }

        DB::transaction(function () use ($strike, $admin, $overturn, $note) {
            $strike->update([
                'appeal_status'     => $overturn ? 'overturned' : 'upheld',
                'appeal_note'       => $note,
                'appeal_decided_by' => $admin->id,
                'appeal_decided_at' => now(),
                'removed_at'        => $overturn ? now() : null,
            ]);

            if ($overturn) {
                $this->restoreStanding($strike->user);
                DB::table('banned_identities')->where('strike_id', $strike->id)->delete();
            }
        });

        $this->notify->appealDecided($strike->fresh());

        return null;
    }

    /*
        After a strike is overturned: whatever suspension the remaining
        strikes still justify, and no more. A restriction needs nothing
        here - it is worked out from the strikes each time.
    */
    private function restoreStanding(User $user): void
    {
        $holding = $user->strikes()->whereNull('removed_at')
            ->whereIn('action', ['suspension', 'ban'])
            ->where(fn ($q) => $q->where('ends_at', '>', now())->orWhere('action', 'ban'))
            ->get();

        if ($holding->isEmpty()) {
            if ($user->is_suspended) {
                $this->suspensions->reinstate($user);
            }

            return;
        }

        $permanent = $holding->contains(fn ($s) => $s->action === 'ban');
        $user->forceFill(['suspended_until' => $permanent ? null : $holding->max('ends_at')])->save();
    }

    /*
        A report dismissed as made in bad faith. The `false_warn_at`th in
        the window earns a warning; any after that pause reporting.
    */
    public function recordFalseReport(User $reporter): void
    {
        $count = Report::where('reporter_id', $reporter->id)
            ->where('baseless', true)
            ->where('resolved_at', '>=', now()->subDays((int) config('moderation.false_window_days')))
            ->count();

        $warnAt = (int) config('moderation.false_warn_at');

        if ($count === $warnAt) {
            $this->notify->falseReportWarning($reporter);
        } elseif ($count > $warnAt) {
            $until = now()->addDays((int) config('moderation.false_pause_days'));
            $reporter->forceFill(['reports_paused_until' => $until])->save();
            $this->notify->reportsPaused($reporter, $until);
        }
    }

    // ── Ban evasion ────────────────────────────────────────────────────────────

    /*
        A confirmed ban is tied to the account's email, phone and Google
        account, hashed, so the same person cannot sign straight back up.
        Kept as hashes: the list exists to say no, not to be read.
    */
    private function banIdentities(Strike $strike): void
    {
        foreach (self::identities($strike->user->email, $strike->user->phone, $strike->user->google_id) as $kind => $hash) {
            DB::table('banned_identities')->insertOrIgnore([
                'kind' => $kind, 'hash' => $hash, 'user_id' => $strike->user_id, 'strike_id' => $strike->id,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }

    public static function isBanned(?string $email = null, ?string $phone = null, ?string $googleId = null): bool
    {
        $ids = self::identities($email, $phone, $googleId);

        return $ids !== [] && DB::table('banned_identities')
            ->where(function ($q) use ($ids) {
                foreach ($ids as $kind => $hash) {
                    $q->orWhere(fn ($q) => $q->where('kind', $kind)->where('hash', $hash));
                }
            })
            ->exists();
    }

    /** @return array<string, string> */
    private static function identities(?string $email, ?string $phone, ?string $googleId): array
    {
        // The last ten digits: 0917..., +63917... and 63917... are one number.
        $digits = substr(preg_replace('/\D/', '', (string) $phone), -10);

        return array_map(fn ($v) => hash('sha256', $v), array_filter([
            'email'  => $email ? strtolower(trim($email)) : null,
            'phone'  => strlen($digits) === 10 ? $digits : null,
            'google' => $googleId ?: null,
        ]));
    }
}
