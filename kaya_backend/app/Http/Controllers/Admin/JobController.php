<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Application;
use App\Models\CreditTransaction;
use App\Models\JobPost;
use App\Services\CreditLedger;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/*
    Every job post on the platform, and the one thing an admin can do to one.

    The panel could see users and their last five posts and nothing else. A
    report about a post, a duplicate, a listing asking for a deposit: the
    only way to act on it was to suspend the whole account. Closing a post
    is the smaller tool, and the one usually needed.
*/
class JobController extends Controller
{
    public function index(Request $request)
    {
        $status = $request->get('status', 'all');
        $search = trim((string) $request->get('search'));

        $jobs = JobPost::query()
            ->with(['employer:id,name,email', 'category:id,name'])
            ->withCount('applications')
            ->when($status !== 'all', fn ($q) => $q->where('status', $status))
            ->when($search !== '', function ($q) use ($search) {
                $q->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('city', 'like', "%{$search}%")
                      ->orWhereHas('employer', fn ($e) => $e->where('name', 'like', "%{$search}%")
                          ->orWhere('email', 'like', "%{$search}%"));
                });
            })
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $counts = JobPost::selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return view('admin.jobs.index', compact('jobs', 'status', 'search', 'counts'));
    }

    public function show(JobPost $job)
    {
        $job->load([
            'employer.employerProfile',
            'category',
            'skills',
            'applications' => fn ($q) => $q->with('worker:id,name,email')->latest(),
        ]);

        // What the employer paid to run it, if anything.
        $charges = CreditTransaction::where('reference_type', 'job')
            ->where('reference_id', $job->id)
            ->latest()
            ->get();

        $history = AdminAction::with('admin:id,name')
            ->where('subject_type', 'job')
            ->where('subject_id', $job->id)
            ->latest('created_at')
            ->get();

        return view('admin.jobs.show', compact('job', 'charges', 'history'));
    }

    /*
        Takes a post off the feed.

        Same shape as the daily expiry sweep: pending applications are
        cancelled and their Barya returned, because the worker paid to be
        read by an employer who now never will. The refund goes through the
        ledger, which refuses to pay the same charge twice.
    */
    public function close(Request $request, JobPost $job, CreditLedger $ledger, NotificationService $notifications)
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:255']]);

        if (! in_array($job->status, ['open', 'in_progress'], true)) {
            return back()->with('error', 'That post is already ' . str_replace('_', ' ', $job->status) . '.');
        }

        $open = $job->applications()->where('status', 'pending')->get();

        DB::transaction(function () use ($job, $open) {
            $job->forceFill(['status' => 'closed'])->save();
            Application::whereIn('id', $open->pluck('id'))->update(['status' => 'cancelled']);
        });

        $charges = CreditTransaction::whereIn(
            'id',
            $open->pluck('credit_transaction_id')->filter()->all(),
        )->get();

        foreach ($charges as $charge) {
            $ledger->refund($charge, 'the post was closed by KAYA');
        }

        $notifications->jobClosedByAdmin($job, $data['reason'], $open->pluck('worker_id'));

        AdminAction::record(
            'job.closed', 'job', $job->id,
            "Closed \"{$job->title}\": {$data['reason']}",
            ['employer_id' => $job->employer_id, 'reason' => $data['reason'], 'applications_refunded' => $charges->count()],
        );

        return back()->with('success', "\"{$job->title}\" was closed. {$open->count()} pending application(s) cancelled and refunded.");
    }
}
