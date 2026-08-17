<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\Realtime\TrackingPositionPushed;
use App\Events\Realtime\TrackingStatePushed;
use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\JobLocationPing;
use App\Models\JobTrackingSession;
use App\Services\RealtimeBroadcaster;
use App\Services\RoutingService;
use Illuminate\Http\Request;

/**
 * Worker location sharing during an active hire.
 *
 * The authorisation rules are the feature — this is continuous location on an
 * identified person, which is sensitive personal information under RA 10173:
 *
 *   • Only the WORKER on the application may consent, ping, or stop.
 *   • Only the EMPLOYER on that same application may read the position.
 *   • Nobody else can read it, including other employers the worker has jobs
 *     with — consent is per-hire, never account-wide.
 *   • Sharing is only possible while that hire is actually in progress, so it
 *     cannot start before a job or continue after it.
 *   • The worker can revoke at any time and revocation is immediate.
 */
class JobTrackingController extends Controller
{
    public function __construct(private RealtimeBroadcaster $realtime) {}

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /**
     * Tracking is only meaningful while the work is actually happening.
     * Anything else — pending, rejected, finished — must not be trackable.
     */
    private function hireIsLive(Application $application): bool
    {
        return $application->status === 'accepted'
            && $application->job?->status === 'in_progress';
    }

    /**
     * POST /applications/{application}/tracking
     * Worker consents and starts sharing.
     */
    public function start(Request $request, Application $application)
    {
        $user = $request->user();

        if ($application->worker_id !== $user->id) {
            return $this->fail('Only the hired worker can share their location', 403);
        }

        $application->load('job');

        if (!$this->hireIsLive($application)) {
            return $this->fail('Location sharing is only available while the job is in progress', 422);
        }

        $session = JobTrackingSession::where('application_id', $application->id)->first();

        if ($session) {
            // Re-consenting after stopping reopens the same session rather than
            // creating a second one (application_id is unique).
            $session->update([
                'consented_at' => now(),
                'stopped_at'   => null,
            ]);
        } else {
            $session = JobTrackingSession::create([
                'application_id' => $application->id,
                'worker_id'      => $application->worker_id,
                'employer_id'    => $application->job->employer_id,
                'consented_at'   => now(),
            ]);
        }

        // The employer may already have the panel open waiting for consent.
        $this->realtime->push(new TrackingStatePushed(
            applicationId: $application->id,
            sharing: true,
            workerName: $user->name,
        ));

        return $this->ok($this->presentForWorker($session), 'Location sharing started');
    }

    /**
     * DELETE /applications/{application}/tracking
     * Worker revokes consent. Immediate.
     */
    public function stop(Request $request, Application $application)
    {
        $user = $request->user();

        if ($application->worker_id !== $user->id) {
            return $this->fail('Only the hired worker can stop sharing', 403);
        }

        $session = JobTrackingSession::where('application_id', $application->id)->first();
        if (!$session) {
            return $this->fail('Location sharing was not active', 404);
        }

        $session->update(['stopped_at' => now()]);

        // Revocation means the trail goes too — keeping it would make "stop
        // sharing" only cosmetic.
        $session->pings()->delete();

        // Without this the employer's map keeps showing the last pin, which is
        // indistinguishable on screen from a live one — revocation would look
        // like it did nothing.
        $this->realtime->push(new TrackingStatePushed(
            applicationId: $application->id,
            sharing: false,
        ));

        return $this->ok($this->presentForWorker($session->fresh()), 'Location sharing stopped');
    }

    /**
     * POST /applications/{application}/tracking/ping
     * Worker reports a position.
     */
    public function ping(Request $request, Application $application)
    {
        $user = $request->user();

        if ($application->worker_id !== $user->id) {
            return $this->fail('Only the hired worker can report a position', 403);
        }

        $data = $request->validate([
            'latitude'   => ['required', 'numeric', 'between:-90,90'],
            'longitude'  => ['required', 'numeric', 'between:-180,180'],
            'accuracy_m' => ['nullable', 'numeric', 'min:0', 'max:100000'],
        ]);

        $application->load('job');

        $session = JobTrackingSession::where('application_id', $application->id)
            ->active()
            ->first();

        if (!$session) {
            return $this->fail('Location sharing is not active', 409);
        }

        // Re-checked on every ping, not just at start: if the job finished or
        // was cancelled while the device kept reporting, sharing ends here.
        if (!$this->hireIsLive($application)) {
            $session->update(['stopped_at' => now()]);

            $this->realtime->push(new TrackingStatePushed(
                applicationId: $application->id,
                sharing: false,
            ));

            return $this->fail('The job is no longer in progress; sharing stopped', 409);
        }

        $ping = JobLocationPing::create([
            'tracking_session_id' => $session->id,
            'latitude'            => $data['latitude'],
            'longitude'           => $data['longitude'],
            'accuracy_m'          => $data['accuracy_m'] ?? null,
            'recorded_at'         => now(),
        ]);

        // This is what makes the employer's pin move on its own.
        $this->realtime->push(new TrackingPositionPushed(
            applicationId: $application->id,
            ping: $ping,
        ));

        return $this->ok(null, 'Position recorded');
    }

    /**
     * GET /applications/{application}/tracking
     *
     * The employer sees the worker's latest position; the worker sees whether
     * they are currently sharing. Anyone else gets a 403.
     */
    public function show(Request $request, Application $application)
    {
        $user = $request->user();
        $application->load('job');

        $isWorker = $application->worker_id === $user->id;
        $isEmployer = $application->job?->employer_id === $user->id;

        if (!$isWorker && !$isEmployer) {
            return $this->fail('Forbidden', 403);
        }

        $session = JobTrackingSession::where('application_id', $application->id)->first();

        if (!$session || !$session->isActive()) {
            return $this->ok([
                'sharing'    => false,
                'can_share'  => $isWorker && $this->hireIsLive($application),
                'viewer'     => $isWorker ? 'worker' : 'employer',
                'latest'     => null,
            ]);
        }

        // The worker gets confirmation they're sharing, not their own trail
        // read back at them; only the employer needs the position.
        if ($isWorker) {
            return $this->ok($this->presentForWorker($session));
        }

        $session->load('latestPing');
        $ping = $session->latestPing;

        /*
            Where the worker is going, so the map can join the two points.

            The panel drew the worker's pin and nothing else — the destination
            was never sent, so there was no second point to draw a line to. The
            panel wants to see someone moving *towards* a place, and a lone dot
            on a map does not show that.

            This is the job's own location, which the employer set when posting
            and already sees on their own job. Nothing new is revealed.
        */
        $job = $application->job;
        $destination = $job?->latitude !== null && $job?->longitude !== null
            ? [
                'latitude'  => (float) $job->latitude,
                'longitude' => (float) $job->longitude,
                'label'     => $job->location,
            ]
            : null;

        /*
            The road route between the two pins.

            A straight line pointed through blocks and across rivers, and the
            distance under it was a figure nobody travels. This is the way the
            worker is actually coming, with an arrival time derived from it.

            Cached by the routing service and fail-soft by design: if the router
            is slow, down or rate-limited this comes back null and the map draws
            the dashed straight line it drew before. Live tracking is a safety
            feature, and it must not go dark because a third party did.
        */
        $route = ($ping !== null && $destination !== null)
            ? app(RoutingService::class)->route(
                (float) $ping->latitude,
                (float) $ping->longitude,
                $destination['latitude'],
                $destination['longitude'],
            )
            : null;

        return $this->ok([
            'sharing'      => true,
            'can_share'    => false,
            'viewer'       => 'employer',
            'worker_name'  => $session->worker?->name,
            'consented_at' => $session->consented_at?->toIso8601String(),
            'destination'  => $destination,
            // Road geometry, distance and ETA. Null when routing is unavailable.
            'route'        => $route,
            'latest'       => $ping === null ? null : [
                'latitude'    => (float) $ping->latitude,
                'longitude'   => (float) $ping->longitude,
                'accuracy_m'  => $ping->accuracy_m,
                'recorded_at' => $ping->recorded_at?->toIso8601String(),
                'age_seconds' => $ping->recorded_at?->diffInSeconds(now()),
                // Straight-line distance. Kept as the fallback figure for when
                // no route is available; the road distance lives on `route`.
                'distance_km' => $destination === null ? null : round(
                    $this->haversineKm(
                        (float) $ping->latitude,
                        (float) $ping->longitude,
                        $destination['latitude'],
                        $destination['longitude'],
                    ),
                    1
                ),
            ],
        ]);
    }

    /**
     * Straight-line distance in kilometres.
     *
     * Deliberately not a road distance. A routing service would be needed for
     * that: the public OSRM demo server is rate-limited and explicitly not for
     * production, and everything better is paid, which conflicts with this
     * project's no-paid-mapping-APIs constraint. So the line on the map is a
     * straight one and this figure matches it — the UI says "in a straight
     * line" rather than implying a travel distance it cannot know.
     */
    private function haversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthKm = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;

        return $earthKm * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    private function presentForWorker(JobTrackingSession $session): array
    {
        return [
            'sharing'      => $session->isActive(),
            'can_share'    => true,
            'viewer'       => 'worker',
            'consented_at' => $session->consented_at?->toIso8601String(),
            'stopped_at'   => $session->stopped_at?->toIso8601String(),
            'latest'       => null,
        ];
    }
}
