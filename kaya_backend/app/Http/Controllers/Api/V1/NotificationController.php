<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\UserNotification;
use Illuminate\Http\Request;

/**
 * The in-app notification centre.
 *
 * Every route is scoped to the signed-in user — there is no way to read
 * someone else's notifications, by id or otherwise.
 *
 * `audience` mirrors the app's worker/employer mode: a hybrid account viewing
 * as a worker shouldn't see applicant alerts for jobs they posted. Omitting
 * the filter returns everything, which is what an unfocused hybrid and a
 * profile-less account should get.
 */
class NotificationController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /** GET /notifications?audience=worker|employer&unread_only=1 */
    public function index(Request $request)
    {
        $data = $request->validate([
            'audience'    => ['nullable', 'in:worker,employer'],
            'unread_only' => ['nullable', 'boolean'],
            'per_page'    => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        // `created_at` is second-resolution, and a single action can write
        // several notifications inside one second — ordering by it alone leaves
        // ties to the storage engine, which shuffles the list between requests
        // and lets paginated rows repeat or vanish. `id` breaks the tie.
        $query = UserNotification::where('user_id', $request->user()->id)
            ->forAudience($data['audience'] ?? null)
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($request->boolean('unread_only')) {
            $query->unread();
        }

        $notifications = $query->paginate($data['per_page'] ?? 20);

        // Same shape the socket pushes — see UserNotification::toPayload().
        $notifications->getCollection()->transform(fn (UserNotification $n) => $n->toPayload());

        return $this->ok($notifications);
    }

    /** GET /notifications/unread-count — drives the bottom-nav badge. */
    public function unreadCount(Request $request)
    {
        $data = $request->validate([
            'audience' => ['nullable', 'in:worker,employer'],
        ]);

        $count = UserNotification::where('user_id', $request->user()->id)
            ->forAudience($data['audience'] ?? null)
            ->unread()
            ->count();

        return $this->ok(['unread_count' => $count]);
    }

    /** PATCH /notifications/{notification}/read */
    public function markRead(Request $request, UserNotification $notification)
    {
        if ($notification->user_id !== $request->user()->id) {
            return $this->fail('Forbidden', 403);
        }

        if (!$notification->isRead()) {
            $notification->update(['read_at' => now()]);
        }

        return $this->ok(['id' => $notification->id, 'is_read' => true], 'Marked as read');
    }

    /**
     * POST /notifications/read-all
     *
     * Honours the audience filter so clearing the badge in worker mode doesn't
     * silently dismiss unread employer notifications the user hasn't seen.
     */
    public function readAll(Request $request)
    {
        $data = $request->validate([
            'audience' => ['nullable', 'in:worker,employer'],
        ]);

        $count = UserNotification::where('user_id', $request->user()->id)
            ->forAudience($data['audience'] ?? null)
            ->unread()
            ->update(['read_at' => now()]);

        return $this->ok(['marked_read_count' => $count], 'All marked as read');
    }
}
