<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/*
    A message from KAYA to everyone, or to one side of the marketplace.

    Delivered as an ordinary notification, so it arrives where people
    already look and is subject to the same per-user switches. Past
    announcements are read back from the audit log, which is where the
    text, the audience and the reach were written when it went out.
*/
class AnnouncementController extends Controller
{
    public function index()
    {
        $sent = AdminAction::with('admin:id,name')
            ->where('action', 'announcement.sent')
            ->latest('created_at')
            ->take(20)
            ->get();

        $reach = [
            UserNotification::AUDIENCE_BOTH     => User::where('user_type', '!=', 'admin')->where('is_suspended', false)->count(),
            UserNotification::AUDIENCE_WORKER   => User::where('user_type', '!=', 'admin')->where('is_suspended', false)->whereHas('workerProfile')->count(),
            UserNotification::AUDIENCE_EMPLOYER => User::where('user_type', '!=', 'admin')->where('is_suspended', false)->whereHas('employerProfile')->count(),
        ];

        return view('admin.announcements.index', compact('sent', 'reach'));
    }

    public function send(Request $request, NotificationService $notifications)
    {
        $data = $request->validate([
            'audience' => ['required', Rule::in([
                UserNotification::AUDIENCE_BOTH, UserNotification::AUDIENCE_WORKER, UserNotification::AUDIENCE_EMPLOYER,
            ])],
            'title' => ['required', 'string', 'max:80'],
            'body'  => ['required', 'string', 'max:500'],
        ]);

        $count = $notifications->announcement($data['audience'], trim($data['title']), trim($data['body']));

        $who = match ($data['audience']) {
            UserNotification::AUDIENCE_WORKER   => 'workers',
            UserNotification::AUDIENCE_EMPLOYER => 'employers',
            default                             => 'everyone',
        };

        AdminAction::record(
            'announcement.sent', 'announcement', null,
            "Sent \"{$data['title']}\" to {$who} ({$count} people)",
            ['audience' => $data['audience'], 'title' => trim($data['title']), 'body' => trim($data['body']), 'reached' => $count],
        );

        return back()->with('success', "Sent to {$count} " . ($count === 1 ? 'person' : 'people') . '.');
    }
}
