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
        // Report a Problem on a hire the other side marked complete.
        'work_not_done' => [
            'label'       => 'Work was not done',
            'description' => 'They marked the job complete, but the work was not done.',
            'severity'    => 'medium',
        ],
        'fake_review' => [
            'label'       => 'Fake or unfair review',
            'description' => 'A review about a job that did not happen, or written to hurt a rating.',
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
     * The violations an administrator can find.
     *
     * `description` is the line the person receives, word for word: the
     * administrator picks a violation and the system sends it. Nobody types.
     *
     * `severity` decides the penalty, through the ladders in
     * config/moderation.php: minor starts at a warning, serious at a
     * suspension, critical is a ban at once.
     */
    public const SUSPENSION = [
        'fraud' => [
            'label'       => 'Scam or fraud',
            'description' => 'You took money, ran a fake job, or cheated another user.',
            'severity'    => 'critical',
        ],
        'fake_documents' => [
            'label'       => 'Fake documents or identity',
            'description' => 'You sent a fake ID, licence or certificate, or pretended to be someone else.',
            'severity'    => 'critical',
        ],
        'harassment' => [
            'label'       => 'Harassment or threats',
            'description' => 'You sent abusive or threatening messages to another user.',
            'severity'    => 'critical',
        ],
        'no_show' => [
            'label'       => 'Did not show up',
            'description' => 'You accepted a job and did not show up on the agreed day, without telling the other person.',
            'severity'    => 'serious',
        ],
        'false_completion' => [
            'label'       => 'Work not done',
            'description' => 'You marked a job complete when the work was not done.',
            'severity'    => 'serious',
        ],
        'misleading_postings' => [
            'label'       => 'Misleading job post',
            'description' => 'Your job post did not match the real work, pay or place.',
            'severity'    => 'serious',
        ],
        'retaliation' => [
            'label'       => 'Getting back at a reporter',
            'description' => 'You threatened, harassed or reported someone back because they reported you.',
            'severity'    => 'serious',
        ],
        'inappropriate_content' => [
            'label'       => 'Inappropriate content',
            'description' => 'You posted offensive, sexual or discriminatory content.',
            'severity'    => 'minor',
        ],
        'fake_reviews' => [
            'label'       => 'Fake review',
            'description' => 'You left or arranged a review that was not honest.',
            'severity'    => 'minor',
        ],
        'spam' => [
            'label'       => 'Spam',
            'description' => 'You sent repeated unwanted messages or advertising.',
            'severity'    => 'minor',
        ],
        'category_misuse' => [
            'label'       => 'Misuse of custom categories',
            'description' => 'You added fake, joke or offensive job categories.',
            'severity'    => 'minor',
        ],
        'policy_violation' => [
            'label'       => 'Other rule broken',
            'description' => 'You broke the KAYA rules.',
            'severity'    => 'minor',
        ],
    ];

    /** How the three severities read on the panel, worst first. */
    public const SEVERITIES = [
        'critical' => 'Critical (Ban at Once)',
        'serious'  => 'Serious',
        'minor'    => 'Minor',
    ];

    /*
        What was reported. Each place in the app with a Report button
        sends one of these.
    */
    public const REPORT_TYPES = [
        'user'              => 'Account',
        'job'               => 'Job Post',
        'message'           => 'Message',
        'community_post'    => 'Community Post',
        'community_comment' => 'Community Comment',
        'review'            => 'Review',
        'application'       => 'Job Problem',
    ];

    /** Report reasons that most often lead to the same violation. */
    private const REPORT_TO_SUSPENSION = [
        'scam'           => 'fraud',
        'fake_identity'  => 'fake_documents',
        'harassment'     => 'harassment',
        'inappropriate'  => 'inappropriate_content',
        'no_show'        => 'no_show',
        'misleading_job' => 'misleading_postings',
        'work_not_done'  => 'false_completion',
        'fake_review'    => 'fake_reviews',
        'spam'           => 'spam',
        'other'          => 'policy_violation',
    ];

    /*
        The lines the system sends. Fixed: an administrator picks a decision
        and these go out, so the same decision always says the same thing.
    */
    public const REPORT_RECEIVED = 'We received your report. Your name is not shown to them.';
    public const REPORTER_ACTION = 'We reviewed your report and took action.';
    public const REPORTER_NO_VIOLATION = 'We reviewed your report and found no violation.';
    public const REPORTER_FALSE = 'Your report was found to be false. Repeated false reports lead to a warning.';
    public const APPEAL_ACCEPTED = 'Your appeal was accepted. The violation was removed.';
    public const APPEAL_REFUSED = 'Your appeal was refused. The violation stays.';

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

    /** The line a violation sends. */
    public static function message(?string $suspensionCode): string
    {
        return self::SUSPENSION[$suspensionCode]['description'] ?? 'You broke the KAYA rules.';
    }

    public static function severity(?string $suspensionCode): string
    {
        return self::SUSPENSION[$suspensionCode]['severity'] ?? 'minor';
    }

    public static function typeLabel(?string $type): string
    {
        return self::REPORT_TYPES[$type ?? 'user'] ?? 'Account';
    }

    /** Scam, fake papers, threats: these skip the strike ladder. */
    public static function isCritical(?string $suspensionCode): bool
    {
        return (self::SUSPENSION[$suspensionCode]['severity'] ?? null) === 'critical';
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
        return ['critical' => 4, 'high' => 3, 'serious' => 3, 'medium' => 2, 'moderate' => 2, 'minor' => 2, 'low' => 1][$severity] ?? 0;
    }
}
