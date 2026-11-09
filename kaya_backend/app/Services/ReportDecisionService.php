<?php

namespace App\Services;

use App\Models\Application;
use App\Models\Report;
use App\Models\Strike;
use App\Models\User;
use App\Support\ModerationReasons;

/*
    One of three decisions on a report, and the system says the rest.

    Give a Violation takes a violation, and the violation decides the penalty
    (see StrikeService) and the line the person receives. No Violation and
    False Report close it; a false report counts against the reporter.
    Nobody types anything.

    A Job Problem report settles the job as well: a violation leaves it Not
    Completed against the reported side; anything else means the work was
    done, and it completes.
*/
class ReportDecisionService
{
    public const DECISIONS = ['violation', 'no_violation', 'false_report'];

    public function __construct(
        private StrikeService $strikes,
        private NotificationService $notify,
        private JobCompletionService $completion,
    ) {}

    /** @return string|null An error to show, or null when it was decided. */
    public function decide(Report $report, string $decision, ?string $reasonCode, User $admin, ?Strike &$strike = null): ?string
    {
        if (! in_array($report->status, ['pending', 'reviewed'], true)) {
            return 'This report has already been closed.';
        }

        $violation = $decision === 'violation';
        $strike = null;

        if ($violation) {
            if ($report->reported === null) {
                return 'The reported account no longer exists.';
            }
            if ($report->reported->isAdmin()) {
                return 'Administrator accounts cannot be given violations.';
            }

            $strike = $this->strikes->issue($report->reported, $reasonCode, $admin, $report);
        }

        $baseless = $decision === 'false_report';

        $report->update([
            'status'          => $violation ? 'resolved' : 'dismissed',
            'resolution_note' => match (true) {
                $violation => 'Violation given: ' . $strike->ruleLabel() . '. ' . $strike->actionLabel() . '.',
                $baseless  => 'False report.',
                default    => 'No violation found.',
            },
            'baseless'        => $baseless,
            'reviewed_by'     => $admin->id,
            'resolved_at'     => now(),
        ]);

        $this->notify->reportDecided($report->fresh());

        if ($report->reported_type === 'application' && $report->subject_id) {
            if ($hire = Application::with('job')->find($report->subject_id)) {
                // The reported side claimed work that did not happen: theirs.
                $fault = $report->reported ? $this->completion->sideFor($hire, $report->reported) : null;
                $this->completion->settleDispute($hire, $violation, $fault);
            }
        }

        if ($baseless && $report->reporter) {
            $this->strikes->recordFalseReport($report->reporter);
        }

        return null;
    }

    public static function outcomeOf(string $decision): string
    {
        return Report::OUTCOMES[match ($decision) {
            'false_report' => 'false',
            'violation'    => 'violation',
            default        => 'no_violation',
        }];
    }
}
