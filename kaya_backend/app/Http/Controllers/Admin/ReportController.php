<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ReportController extends Controller
{
    public function index(Request $request)
    {
        $status = $request->get('status', 'pending');

        $reports = Report::with(['reporter', 'reported'])
            ->when($status !== 'all', fn ($q) => $q->where('status', $status))
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('admin.reports.index', compact('reports', 'status'));
    }

    public function resolve(Request $request, Report $report)
    {
        $request->validate(['status' => ['required', 'in:resolved,dismissed']]);

        $report->update([
            'status' => $request->get('status'),
            'reviewed_by' => Auth::id(),
        ]);

        return back()->with('success', 'Report updated.');
    }
}
