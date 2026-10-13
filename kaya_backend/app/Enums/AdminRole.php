<?php

namespace App\Enums;

/*
    What each kind of administrator may do. See the migration for why there
    is more than one kind.

    Abilities are named for the work rather than for the screen, so a new page
    joins an existing ability instead of adding a role:

      analytics          reading. The dashboard, analytics and the exports
      verify             identity and business papers, and TIN checks
      support            the support threads
      content            reports, the community board, reviews, closing a job
      users              the user list and a profile, read
      suspend            suspending and reinstating an account
      finance            the Barya ledger, read
      finance.adjust     adding or taking Barya by hand
      catalogue          categories, skills and synonyms: adding and renaming
      catalogue.destroy  hiding a category, merging one, deleting a skill
      platform           pricing, announcements and the home banners
      audit              the audit log
      admins             who the administrators are

    The old five (moderate, users, finance, settings, analytics) were too
    coarse for anybody narrower than a moderator: a person brought in to
    clear the verification queue also got the reports, the board and the
    support inbox. Everybody keeps `analytics`, because an administrator who
    cannot see the dashboard cannot do the rest of their job either.

    The Sub-admin is everything except the four the owner keeps (decision D3
    in PLAN-major-update.md): managing administrators, the platform settings,
    adjusting Barya by hand, and deleting or merging the catalogue.
*/
enum AdminRole: string
{
    case SUPER = 'super';
    case SUB_ADMIN = 'sub_admin';
    case MODERATOR = 'moderator';
    case VERIFIER = 'verifier';
    case SUPPORT_AGENT = 'support_agent';
    case CONTENT_MODERATOR = 'content_moderator';
    case FINANCE = 'finance';
    case ANALYST = 'analyst';

    public const ANALYTICS = 'analytics';
    public const VERIFY = 'verify';
    public const SUPPORT = 'support';
    public const CONTENT = 'content';
    public const USERS = 'users';
    public const SUSPEND = 'suspend';
    public const FINANCE_VIEW = 'finance';
    public const FINANCE_ADJUST = 'finance.adjust';
    public const CATALOGUE = 'catalogue';
    public const CATALOGUE_DESTROY = 'catalogue.destroy';
    public const PLATFORM = 'platform';
    public const AUDIT = 'audit';
    public const ADMINS = 'admins';

    /** Every ability. */
    public const ALL = [
        self::ANALYTICS, self::VERIFY, self::SUPPORT, self::CONTENT, self::USERS, self::SUSPEND,
        self::FINANCE_VIEW, self::FINANCE_ADJUST, self::CATALOGUE, self::CATALOGUE_DESTROY,
        self::PLATFORM, self::AUDIT, self::ADMINS,
    ];

    /** What only the owner keeps. */
    private const OWNER_ONLY = [
        self::ADMINS, self::PLATFORM, self::FINANCE_ADJUST, self::CATALOGUE_DESTROY,
    ];

    /** @return list<string> */
    public function abilities(): array
    {
        return match ($this) {
            self::SUPER => self::ALL,
            self::SUB_ADMIN => array_values(array_diff(self::ALL, self::OWNER_ONLY)),
            self::MODERATOR => [self::ANALYTICS, self::VERIFY, self::SUPPORT, self::CONTENT, self::USERS, self::SUSPEND],
            self::VERIFIER => [self::ANALYTICS, self::VERIFY],
            self::SUPPORT_AGENT => [self::ANALYTICS, self::SUPPORT, self::USERS],
            // Reads the accounts it is judging; suspends through a report.
            self::CONTENT_MODERATOR => [self::ANALYTICS, self::CONTENT, self::USERS],
            self::FINANCE => [self::ANALYTICS, self::FINANCE_VIEW, self::FINANCE_ADJUST],
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
            self::SUB_ADMIN => 'Sub-admin',
            self::MODERATOR => 'Moderator',
            self::VERIFIER => 'Verifier',
            self::SUPPORT_AGENT => 'Support agent',
            self::CONTENT_MODERATOR => 'Content moderator',
            self::FINANCE => 'Finance',
            self::ANALYST => 'Analyst',
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
