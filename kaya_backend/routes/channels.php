<?php

use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobTrackingSession;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast channels
|--------------------------------------------------------------------------
|
| These callbacks answer one question: may this authenticated user listen to
| this channel? Returning false refuses the subscription.
|
| This is the whole security boundary of the realtime layer. A channel name is
| guessable — `application.41.tracking` is two integers — so the rule below is
| the only thing standing between a stranger and a live GPS feed of a worker.
| Treat every callback here as a permission check on sensitive data, and mirror
| the controller that owns the same resource rather than inventing a looser
| rule: the socket must never expose what an HTTP request would refuse.
|
| Registered on the API stack with `auth:sanctum` (see bootstrap/app.php), so
| `$user` resolves from the same bearer token the app already holds.
|
*/

/**
 * Your own notification feed.
 *
 * Deliberately keyed on the user, not on worker/employer — a hybrid account has
 * one inbox and filters it by audience, exactly as the REST endpoint does.
 */
Broadcast::channel('user.{userId}', function (User $user, int $userId) {
    return $user->id === $userId;
});

/**
 * One conversation's messages.
 *
 * Mirrors ConversationController: only the two parties on the thread. It
 * intentionally does NOT require the conversation to be unlocked — a locked
 * thread has no messages to broadcast anyway, and re-checking lock state on
 * every reconnect would drop the socket at the moment acceptance unlocks it.
 */
Broadcast::channel('conversation.{conversationId}', function (User $user, int $conversationId) {
    $conversation = Conversation::find($conversationId);

    if (!$conversation) {
        return false;
    }

    return $conversation->employer_id === $user->id
        || $conversation->worker_id === $user->id;
});

/**
 * A worker's live position during one hire.
 *
 * The strictest channel in the app, and the rules match JobTrackingController
 * exactly:
 *
 *   • Only the employer on this application may listen. The worker is the
 *     source of the data and has no reason to subscribe to their own trail.
 *   • Only while the hire is actually live (accepted application, in-progress
 *     job).
 *   • Only while consent is currently active — a revoked session must refuse
 *     new subscriptions, not merely stop producing pings.
 *
 * That last check is what makes revocation real: the controller deletes the
 * stored trail on stop, and this refuses anyone trying to re-attach afterwards.
 */
Broadcast::channel('application.{applicationId}.tracking', function (User $user, int $applicationId) {
    $application = Application::with('job')->find($applicationId);

    if (!$application || $application->job?->employer_id !== $user->id) {
        return false;
    }

    $hireIsLive = $application->status === 'accepted'
        && $application->job?->status === 'in_progress';

    if (!$hireIsLive) {
        return false;
    }

    return JobTrackingSession::where('application_id', $application->id)
        ->active()
        ->exists();
});
