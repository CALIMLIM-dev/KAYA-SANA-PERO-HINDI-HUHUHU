<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\User;
use Illuminate\Http\Request;

/** Who did what in this panel, newest first. Read-only by design. */
class AuditController extends Controller
{
    public function index(Request $request)
    {
        $area = $request->get('area', 'all');
        $adminId = $request->integer('admin');

        $actions = AdminAction::query()
            ->with('admin:id,name')
            ->when($area !== 'all', fn ($q) => $q->where('action', 'like', "{$area}.%"))
            ->when($adminId > 0, fn ($q) => $q->where('admin_id', $adminId))
            ->latest('created_at')
            ->latest('id')
            ->paginate(30)
            ->withQueryString();

        $areas = AdminAction::selectRaw("SUBSTR(action, 1, INSTR(action, '.') - 1) as area")
            ->distinct()
            ->pluck('area')
            ->filter()
            ->sort()
            ->values();

        $admins = User::where('user_type', 'admin')->orderBy('name')->get(['id', 'name']);

        return view('admin.audit.index', compact('actions', 'area', 'areas', 'adminId', 'admins'));
    }
}
