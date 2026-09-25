<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\Verification;
use Illuminate\Support\Facades\DB;

/*
    What the admin layout polls.

    The panel is server rendered, so a page shows the moment it was opened
    and nothing after: a verification that came in while the queue was on
    screen was invisible until somebody pressed refresh. Reverb is off on
    the server by design, so this is a poll. It answers with a stamp that
    changes whenever anything an admin page shows has changed, and the two
    queue counts the sidebar badges.

    The stamp is the newest row and newest change across the tables the
    panel reads. Cheap: one MAX per table, all indexed columns.
*/
class PulseController extends Controller
{
    /** Tables whose rows the admin pages list. */
    private const TABLES = [
        'users',
        'verifications',
        'reports',
        'reviews',
        'jobs_posts',
        'applications',
        'community_posts',
        'credit_transactions',
        'credit_payments',
        'admin_actions',
        'employer_profiles',
    ];

    public function index()
    {
        $parts = [];

        foreach (self::TABLES as $table) {
            $hasUpdated = in_array($table, ['users', 'verifications', 'reports', 'reviews', 'jobs_posts', 'applications', 'community_posts', 'credit_payments', 'employer_profiles'], true);

            $row = DB::table($table)
                ->selectRaw($hasUpdated
                    ? 'MAX(id) as newest, MAX(updated_at) as changed'
                    : 'MAX(id) as newest, NULL as changed')
                ->first();

            $parts[] = $table . ':' . ($row->newest ?? 0) . ':' . ($row->changed ?? '');
        }

        return response()->json([
            'stamp'  => md5(implode('|', $parts)),
            'queues' => [
                'verifications' => Verification::where('status', 'pending')->count(),
                'reports'       => Report::where('status', 'pending')->count(),
                // Posts nobody outside KAYA can see until somebody looks.
                'community'     => \App\Models\CommunityPost::where('status', \App\Models\CommunityPost::STATUS_PENDING)->count(),
            ],
        ]);
    }
}
