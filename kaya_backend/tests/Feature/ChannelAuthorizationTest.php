<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\JobTrackingSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Who may listen on which realtime channel.
 *
 * This is the security boundary of the WebSocket layer and it deserves tests
 * more than most things in this codebase, because the failure is silent. A
 * channel name is guessable — `application.41.tracking` is two integers — and a
 * too-permissive rule doesn't throw, doesn't log, and doesn't show up in the
 * UI. It just quietly streams a worker's live location to whoever asked.
 *
 * Everything here goes through the real /api/broadcasting/auth endpoint rather
 * than calling the channel closures directly, so it also covers the wiring:
 * that the route exists, runs on the API stack, and resolves the user from a
 * Sanctum token instead of a session.
 */
class ChannelAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // phpunit.xml pins BROADCAST_CONNECTION=null, and NullBroadcaster::auth()
        // authorises everything without consulting routes/channels.php — so on
        // the default test driver every assertion below passes trivially and
        // proves nothing. Point at the real driver so the channel callbacks
        // actually run. Authorisation is local (channel closure + HMAC signing),
        // so this needs no Reverb process.
        config([
            'broadcasting.default'                   => 'reverb',
            'broadcasting.connections.reverb.key'    => 'test-key',
            'broadcasting.connections.reverb.secret' => 'test-secret',
            'broadcasting.connections.reverb.app_id' => 'test-app',
        ]);

        // Channels are registered on a *broadcaster instance*, not globally, and
        // bootstrap/app.php registered them against the null driver back when it
        // was still the default. Switching the default above hands us a fresh
        // reverb broadcaster with an empty channel list — and an unmatched
        // channel name also answers 403, so without this re-registration every
        // "must refuse" assertion would pass for entirely the wrong reason.
        require base_path('routes/channels.php');
    }

    private function authorize(User $as, string $channel)
    {
        return $this->actingAs($as, 'sanctum')->postJson('/api/broadcasting/auth', [
            'socket_id'    => '1234.5678',
            'channel_name' => $channel,
        ]);
    }

    private function assertGranted(User $as, string $channel): void
    {
        $this->authorize($as, $channel)
            ->assertOk()
            ->assertJsonStructure(['auth']);
    }

    private function assertRefused(User $as, string $channel): void
    {
        $this->authorize($as, $channel)->assertForbidden();
    }

    // ── user.{id} ────────────────────────────────────────────────────────────

    /** @test */
    public function a_user_may_only_listen_to_their_own_notification_feed()
    {
        $me     = User::factory()->create();
        $anyone = User::factory()->create();

        $this->assertGranted($me, 'private-user.' . $me->id);
        $this->assertRefused($anyone, 'private-user.' . $me->id);
    }

    // ── conversation.{id} ────────────────────────────────────────────────────

    /** @test */
    public function only_the_two_parties_may_listen_to_a_conversation()
    {
        $employer  = User::factory()->create();
        $worker    = User::factory()->create();
        $outsider  = User::factory()->create();

        $job = $this->job($employer);

        $conversation = Conversation::create([
            'job_id'      => $job->id,
            'employer_id' => $employer->id,
            'worker_id'   => $worker->id,
            'status'      => 'unlocked',
        ]);

        $channel = 'private-conversation.' . $conversation->id;

        $this->assertGranted($employer, $channel);
        $this->assertGranted($worker, $channel);
        $this->assertRefused($outsider, $channel);
    }

    /** @test */
    public function a_missing_conversation_is_refused_rather_than_erroring()
    {
        $this->assertRefused(User::factory()->create(), 'private-conversation.999999');
    }

    // ── application.{id}.tracking ────────────────────────────────────────────

    /** @test */
    public function the_employer_may_watch_a_live_consented_hire()
    {
        [$employer, , $application] = $this->liveTrackedHire();

        $this->assertGranted($employer, 'private-application.' . $application->id . '.tracking');
    }

    /** @test */
    public function the_worker_may_not_subscribe_to_their_own_location_feed()
    {
        // The worker is the source of this data, not a consumer of it. Letting
        // them subscribe would widen the channel for no feature gain.
        [, $worker, $application] = $this->liveTrackedHire();

        $this->assertRefused($worker, 'private-application.' . $application->id . '.tracking');
    }

    /** @test */
    public function an_unrelated_user_may_not_watch_a_hire()
    {
        [, , $application] = $this->liveTrackedHire();

        $this->assertRefused(User::factory()->create(), 'private-application.' . $application->id . '.tracking');
    }

    /** @test */
    public function revoking_consent_closes_the_channel_to_new_subscribers()
    {
        // The heart of the feature: "stop sharing" has to mean the employer
        // cannot re-attach, not merely that pings stop arriving.
        [$employer, , $application, $session] = $this->liveTrackedHire();

        $channel = 'private-application.' . $application->id . '.tracking';
        $this->assertGranted($employer, $channel);

        $session->update(['stopped_at' => now()]);

        $this->assertRefused($employer, $channel);
    }

    /** @test */
    public function a_finished_job_closes_the_channel_even_with_consent_on_record()
    {
        // Consent was given for a job that is now over. Sharing must not
        // outlive the work it was granted for.
        [$employer, , $application] = $this->liveTrackedHire();

        $application->job->update(['status' => 'completed']);

        $this->assertRefused($employer, 'private-application.' . $application->id . '.tracking');
    }

    /** @test */
    public function a_pending_application_is_not_trackable()
    {
        [$employer, , $application] = $this->liveTrackedHire();

        $application->update(['status' => 'pending']);

        $this->assertRefused($employer, 'private-application.' . $application->id . '.tracking');
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private function job(User $employer, string $status = 'open'): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'Two days of electrical work.',
            'budget_min'  => 1500,
            'status'      => $status,
        ]);
    }

    /** @return array{0: User, 1: User, 2: Application, 3: JobTrackingSession} */
    private function liveTrackedHire(): array
    {
        $employer = User::factory()->create();
        $worker   = User::factory()->create();

        $job = $this->job($employer, 'in_progress');

        $application = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);
        $application->setRelation('job', $job);

        $session = JobTrackingSession::create([
            'application_id' => $application->id,
            'worker_id'      => $worker->id,
            'employer_id'    => $employer->id,
            'consented_at'   => now(),
        ]);

        return [$employer, $worker, $application, $session];
    }
}
