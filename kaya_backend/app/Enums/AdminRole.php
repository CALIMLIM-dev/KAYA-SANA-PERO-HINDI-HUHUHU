<?php

namespace App\Enums;

/*
    What each kind of administrator may do. See the migration for why there
    is more than one kind.

    Abilities are named for the work rather than for the screen, so a new page
    joins an existing ability instead of adding a fourth role. Five cover the
    panel:

      moderate   the queues and what is in them - verifications, reports, the
                 community board, reviews, closing a job
      users      the people themselves: the user list, a profile, suspending
                 and reinstating an account
      finance    Barya. Balances, adjustments, payments
      settings   the shape of the platform: categories and skills, the
                 settings page, announcements, and who the admins are
      analytics  reading. The dashboard, analytics and the exports

    Everybody has `analytics`, because an administrator who cannot see the
    dashboard cannot do the rest of their job either.
*/
enum AdminRole: string
{
    case SUPER = 'super';
    case MODERATOR = 'moderator';
    case ANALYST = 'analyst';

    public const MODERATE = 'moderate';
    public const USERS = 'users';
    public const FINANCE = 'finance';
    public const SETTINGS = 'settings';
    public const ANALYTICS = 'analytics';

    /** Every ability, in the order the sidebar uses them. */
    public const ALL = [
        self::ANALYTICS, self::MODERATE, self::USERS, self::FINANCE, self::SETTINGS,
    ];

    /** @return list<string> */
    public function abilities(): array
    {
        return match ($this) {
            self::SUPER => self::ALL,
            self::MODERATOR => [self::ANALYTICS, self::MODERATE, self::USERS],
            self::ANALYST => [self::ANALYTICS],
        };
    }

    public function can(string $ability): bool
    {
        return in_array($ability, $this->abilities(), true);
    }

    public function label(): string
    {
        return match ($this) {
            self::SUPER => 'Super admin',
            self::MODERATOR => 'Moderator',
            self::ANALYST => 'Analyst',
        };
    }

    /** One line for the screen where an admin's role is chosen. */
    public function description(): string
    {
        return match ($this) {
            self::SUPER => 'Everything, including who the other administrators are.',
            self::MODERATOR => 'The queues and the people in them. No Barya, no settings.',
            self::ANALYST => 'Reads the dashboard, the analytics and the exports. Changes nothing.',
        };
    }

    /*
        An admin row with no role set.

        Only an account that predates the column, and taking its keys away
        would lock whoever runs the panel out of it. Super is what they had.
    */
    public static function fromUser(?string $stored): self
    {
        return self::tryFrom((string) $stored) ?? self::SUPER;
    }
}
