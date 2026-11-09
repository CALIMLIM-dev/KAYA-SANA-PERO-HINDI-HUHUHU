<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\BugReport;
use App\Models\ServerError;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/*
    Something's Broken reports from the app, with what KAYA attached: the
    app version, the phone, and server errors on the person's account just
    before they reported. Marking one Fixed tells the person.
*/
class BugReportController extends Controller
{
    public function index(Request $request)
    {
        $show = $request->get('show') === 'fixed' ? 'fixed' : 'new';

        $reports = BugReport::with('user:id,name')
            ->where('status', $show)
            ->latest('id')
            ->paginate(20)
            ->withQueryString();

        $counts = BugReport::selectRaw('status, count(*) as n')->groupBy('status')->pluck('n', 'status');

        $errors = ServerError::whereIn('id', $reports->getCollection()->pluck('server_error_ids')->flatten()->filter()->unique())
            ->get()->keyBy('id');

        return view('admin.bugs.index', compact('reports', 'show', 'counts', 'errors'));
    }

    public function screenshot(BugReport $bug)
    {
        $disk = Storage::disk(config('filesystems.documents'));
        abort_if(blank($bug->screenshot_path) || ! $disk->exists($bug->screenshot_path), 404);

        return $disk->response($bug->screenshot_path);
    }

    public function fix(BugReport $bug, NotificationService $notifications)
    {
        if ($bug->status === 'fixed') {
            return back();
        }

        $bug->forceFill(['status' => 'fixed', 'fixed_at' => now()])->save();

        if ($bug->user) {
            $notifications->bugFixed($bug->user, (string) config('kaya.app.latest_version', ''));
        }

        AdminAction::record('bug.fixed', 'bug_report', $bug->id, 'Marked a bug report fixed: ' . $bug->issueLabel());

        return back()->with('success', 'Marked fixed. The person was told.');
    }
}
