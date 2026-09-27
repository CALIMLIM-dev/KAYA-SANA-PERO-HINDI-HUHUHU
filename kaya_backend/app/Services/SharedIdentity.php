<?php

namespace App\Services;

use App\Models\User;

/*
    The facts that belong to the account rather than to one of its profiles.

    A hybrid account is one person with two roles, not two people. Their name
    is their name, their face is their face, their verified ID is verified
    once, and they live in one place. Those four were stored per profile, so
    setting up the second one asked for all of them again and answering
    differently left the same person disagreeing with themselves - which is
    exactly the bug list this came from: the same picture when hybrid, the
    name lagging on the second profile, the location missing on it.

    Name and verification were already single: they live on users. The photo
    became single when both uploads started writing users.avatar. Location is
    the one still duplicated, and this is what keeps the copies in step.

    A COMPANY employer is never hybrid - the rule forbids it - so nothing
    here has to reconcile a company's address with a person's home.
*/
class SharedIdentity
{
    /**
     * Writes a location onto every profile this account holds.
     *
     * Called after either side saves one, so the other side follows rather
     * than keeping a stale copy. The display string and the structured
     * fields move together: a label without an id is the state that makes a
     * profile invisible to proximity search.
     */
    public function spreadLocation(
        User $user,
        ?string $label,
        ?int $locationId,
        ?float $latitude,
        ?float $longitude,
    ): void {
        if (blank($label) && $locationId === null) {
            return;
        }

        $fields = [
            'location'    => $label,
            'location_id' => $locationId,
            'latitude'    => $latitude,
            'longitude'   => $longitude,
        ];

        $user->workerProfile?->forceFill($fields)->save();
        $user->employerProfile?->forceFill($fields)->save();

        // The account's own display city, which the feed and the header read.
        if (filled($label)) {
            $user->forceFill(['city' => $label])->save();
        }
    }

    /*
        What the second profile does not need to ask for.

        The setup flow reads this to skip the steps already answered: a
        person who has been verified once is not verified twice, and a name
        typed on the first profile is the same name on the second.
    */
    public function known(User $user): array
    {
        $worker = $user->workerProfile;
        $employer = $user->employerProfile;

        $location = $worker?->location ?: $employer?->location;

        return [
            'name'         => filled($user->name),
            'photo'        => filled($user->resolvedAvatarUrl()),
            'verification' => (bool) $user->is_verified,
            'location'     => filled($location),
            // The values themselves are not repeated here: /me already
            // sends known_location, which resolves the place to the grain
            // each side of the app asks for. Two payloads carrying the same
            // fact is the drift this class exists to stop.
            'location_label' => $location,
        ];
    }
}
