<?php

namespace App\Support;

/**
 * The catalogue of reasons for reporting a user and for suspending one.
 *
 * One list, used by the app's report sheet, the API that validates it, the
 * admin queue that displays it and the suspension dialog that acts on it.
 * The wording previously lived inside a Blade `<select>`, which meant the app
 * could send a reason the panel had never heard of and nobody would notice.
 *
 * Records store the **code**, never the label. Codes are stable; labels are
 * copy. Rewording "Spam or scam activity" tomorrow must not orphan every row
 * suspended under the old wording, and grouping a year of reports by a display
 * string only works until somebody fixes a typo.
 */
class ModerationReasons
{
    /**
     * What a user picks when reporting somebody.
     *
     * Deliberately short. A long list makes people choose the first plausible
     * entry rather than the right one, and every extra option is another
     * bucket an administrator has to learn to read.
     *
     * `severity` drives queue ordering, not the outcome — a human still decides
     * that. It exists so a safety report does not sit under twenty spam reports.
     */
    public const REPORT = [
        'scam' => [
            'label'       => 'Scam or fraud',
            'description' => 'Asked for money up front, fake job, or payment that never came.',
            'severity'    => 'high',
        ],
        'fake_identity' => [
            'label'       => 'Fake identity or credentials',
            'description' => 'Pretending to be someone else, or claiming licences they do not hold.',
            'severity'    => 'high',
        ],
        'harassment' => [
            'label'       => 'Harassment or threats',
            'description' => 'Abusive messages, intimidation, or unwanted contact.',
            'severity'    => 'high',
        ],
        'inappropriate' => [
            'label'       => 'Inappropriate content',
            'description' => 'Offensive photos, sexual content, or discriminatory language.',
            'severity'    => 'medium',
        ],
        'no_show' => [
            'label'       => 'Did not show up',
            'description' => 'Accepted the job and never arrived, with no notice.',
            'severity'    => 'medium',
        ],
        'misleading_job' => [
            'label'       => 'Misleading job post',
            'description' => 'The work, pay, or location was not what was advertised.',
            'severity'    => 'medium',
        ],
        'spam' => [
            'label'       => 'Spam',
            'description' => 'Repeated unwanted messages or advertising.',
            'severity'    => 'low',
        ],
        'other' => [
            'label'       => 'Something else',
            'description' => 'Tell us what happened in your own words.',
            'severity'    => 'low',
        ],
    ];

    /**
     * What an administrator picks when suspending an account.
     *
     * `default_days` is a starting point the dialog fills in, not a rule — it
     * can be changed before confirming. `null` means the reason normally
     * warrants a permanent ban, which is why those are the ones tied to fraud
     * and safety rather than to sloppiness.
     */
    public const SUSPENSION = [
        'fraud' => [
            'label'        => 'Scam or fraudulent activity',
            'description'  => 'Took money, ran a fake job, or defrauded another user.',
            'severity'     => 'critical',
            'default_days' => null,
        ],
        'fake_documents' => [
            'label'        => 'Fake documents or identity',
            'description'  => 'Submitted a forged ID, licence, or certificate.',
            'severity'     => 'critical',
            'default_days' => null,
        ],
        'harassment' => [
            'label'        => 'Harassment or threats',
            'description'  => 'Abused, threatened, or intimidated another user.',
            'severity'     => 'critical',
            'default_days' => null,
        ],
        'inappropriate_content' => [
            'label'        => 'Inappropriate content',
            'description'  => 'Offensive, sexual, or discriminatory material on the profile or in messages.',
            'severity'     => 'serious',
            'default_days' => 30,
        ],
        'repeated_no_show' => [
            'label'        => 'Repeatedly failed to show up',
            'description'  => 'Accepted work and did not appear, more than once.',
            'severity'     => 'serious',
            'default_days' => 30,
        ],
        'misleading_postings' => [
            'label'        => 'Misleading job postings',
            'description'  => 'Advertised work, pay, or conditions that did not match reality.',
            'severity'     => 'serious',
            'default_days' => 14,
        ],
        'fake_reviews' => [
            'label'        => 'Fake reviews or rating abuse',
            'description'  => 'Left or arranged reviews to manipulate a rating.',
            'severity'     => 'moderate',
            'default_days' => 14,
        ],
        'spam' => [
            'label'        => 'Spam',
            'description'  => 'Repeated unsolicited messages or advertising.',
            'severity'     => 'moderate',
            'default_days' => 7,
        ],
        'policy_violation' => [
            'label'        => 'Other policy violation',
            'description'  => 'Breached the terms in a way not covered above. Explain in the note.',
            'severity'     => 'moderate',
            'default_days' => 7,
        ],
    ];

    /** Report reasons that most often lead to the same suspension reason. */
    private const REPORT_TO_SUSPENSION = [
        'scam'           => 'fraud',
        'fake_identity'  => 'fake_documents',
        'harassment'     => 'harassment',
        'inappropriate'  => 'inappropriate_content',
        'no_show'        => 'repeated_no_show',
        'misleading_job' => 'misleading_postings',
        'spam'           => 'spam',
        'other'          => 'policy_violation',
    ];

    /** @return string[] Valid report codes, for validation rules. */
    public static function reportCodes(): array
    {
        return array_keys(self::REPORT);
    }

    /** @return string[] Valid suspension codes, for validation rules. */
    public static function suspensionCodes(): array
    {
        return array_keys(self::SUSPENSION);
    }

    /**
     * Human label for a stored code.
     *
     * Falls back to the code itself rather than to an empty string, so a row
     * written before this catalogue existed still shows something an
     * administrator can read instead of a blank cell.
     */
    public static function reportLabel(?string $code): string
    {
        return self::REPORT[$code]['label'] ?? ($code ? str_replace('_', ' ', ucfirst($code)) : 'Not given');
    }

    public static function suspensionLabel(?string $code): string
    {
        return self::SUSPENSION[$code]['label'] ?? ($code ? str_replace('_', ' ', ucfirst($code)) : 'Not given');
    }

    public static function reportSeverity(?string $code): string
    {
        return self::REPORT[$code]['severity'] ?? 'low';
    }

    /** Which suspension reason the admin dialog should pre-select from a report. */
    public static function suggestedSuspension(?string $reportCode): ?string
    {
        return self::REPORT_TO_SUSPENSION[$reportCode] ?? null;
    }

    /**
     * Ordering weight, highest first. Used so the queue surfaces safety reports
     * above spam rather than strictly newest-first.
     */
    public static function severityRank(string $severity): int
    {
        return ['critical' => 4, 'high' => 3, 'serious' => 3, 'medium' => 2, 'moderate' => 2, 'low' => 1][$severity] ?? 0;
    }
}
