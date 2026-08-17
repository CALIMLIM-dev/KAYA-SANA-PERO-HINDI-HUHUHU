<?php

namespace App\Services;

use App\Models\User;
use App\Support\ModerationReasons;
use Illuminate\Support\Facades\DB;

/**
 * The one place an account is suspended or reinstated.
 *
 * Suspension used to be a two-line `forceFill` inside a controller. Doing it
 * from a second place — acting on a report — would have meant copying that,
 * and the copy would eventually disagree about what a suspension records.
 *
 * Every suspension here writes who decided, when, on what grounds, and whether
 * it ends. A ban nobody can explain later is indistinguishable from a mistake.
 */
class SuspensionService
{
    /**
     * @param  string  $duration  Days as a string, or 'permanent'.
     */
    public function suspend(
        User $user,
        string $reasonCode,
        string $duration,
        ?string $note,
        User $admin,
    ): void {
        $until = $duration === 'permanent'
            ? null
            : now()->addDays((int) $duration);

        DB::transaction(function () use ($user, $reasonCode, $until, $note, $admin) {
            // forceFill: suspension fields are intentionally not mass-assignable,
            // so no request can ever set them by posting the right field name.
            $user->forceFill([
                'is_suspended'          => true,
                'suspended_reason'      => ModerationReasons::suspensionLabel($reasonCode),
                'suspended_reason_code' => $reasonCode,
                'suspended_by'          => $admin->id,
                'suspended_at'          => now(),
                'suspended_until'       => $until,
                'suspension_note'       => $note,
            ])->save();

            // A suspended account must not keep a live session on a phone
            // somewhere. Without this the ban only takes effect when their
            // current token happens to expire.
            $user->tokens()->delete();
        });
    }

    public function reinstate(User $user): void
    {
        $user->forceFill([
            'is_suspended'          => false,
            'suspended_reason'      => null,
            'suspended_reason_code' => null,
            'suspended_by'          => null,
            'suspended_at'          => null,
            'suspended_until'       => null,
            'suspension_note'       => null,
        ])->save();
    }

    /**
     * Lifts every temporary suspension that has run its course.
     *
     * Returns the number lifted. Without this a "7 day suspension" is a
     * permanent one that an administrator has to remember to undo, which is a
     * promise the product cannot keep.
     */
    public function liftExpired(): int
    {
        $due = User::where('is_suspended', true)
            ->whereNotNull('suspended_until')
            ->where('suspended_until', '<=', now())
            ->get();

        foreach ($due as $user) {
            $this->reinstate($user);
        }

        return $due->count();
    }
}
