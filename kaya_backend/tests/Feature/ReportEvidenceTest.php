<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\Report;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The panel: "Provide substantial supporting evidence and relevant details
    when submitting or processing reports involving either party to
    facilitate proper evaluation and resolution."

    Submitting: a written account, photos, and a saved copy of what was
    reported. Processing: all of it on the admin page, and a decision the
    system words the same way every time.
*/
class ReportEvidenceTest extends TestCase
{
    use RefreshDatabase;

    private User $reporter;
    private User $reported;

    protected function setUp(): void
    {
        parent::setUp();
        $this->reporter = User::factory()->create(['name' => 'Rosa Bautista']);
        $this->reported = User::factory()->create(['name' => 'Juan Dela Cruz']);
    }

    private function file(array $extra = [])
    {
        return $this->actingAs($this->reporter, 'sanctum')->postJson('/api/v1/reports', array_merge([
            'reported_id' => $this->reported->id,
            'reason_code' => 'scam',
            'description' => 'Asked for a 2000 peso deposit before starting.',
        ], $extra));
    }

    #[Test]
    public function a_report_needs_an_account_of_what_happened(): void
    {
        $this->file(['description' => 'bad'])->assertStatus(422)->assertJsonValidationErrors('description');
        $this->file(['description' => null])->assertStatus(422);
        $this->assertSame(0, Report::count());
    }

    #[Test]
    public function the_reported_message_is_kept_as_it_was(): void
    {
        $thread = Conversation::create([
            'pair_low' => min($this->reporter->id, $this->reported->id),
            'pair_high' => max($this->reporter->id, $this->reported->id),
            'employer_id' => $this->reporter->id, 'worker_id' => $this->reported->id, 'status' => 'unlocked',
        ]);
        $message = Message::create(['conversation_id' => $thread->id, 'sender_id' => $this->reported->id,
            'message_text' => 'Send the deposit to my GCash first.']);

        $this->file(['subject_type' => 'message', 'subject_id' => $message->id])->assertCreated();
        $message->delete();

        $snapshot = Report::firstOrFail()->snapshot;
        $this->assertSame('Message', $snapshot['kind']);
        $this->assertSame('Send the deposit to my GCash first.', $snapshot['text']);
    }

    #[Test]
    public function a_message_that_is_not_theirs_is_not_copied(): void
    {
        $stranger = User::factory()->create();
        $thread = Conversation::create([
            'pair_low' => min($stranger->id, $this->reported->id),
            'pair_high' => max($stranger->id, $this->reported->id),
            'employer_id' => $stranger->id, 'worker_id' => $this->reported->id, 'status' => 'unlocked',
        ]);
        $private = Message::create(['conversation_id' => $thread->id, 'sender_id' => $this->reported->id,
            'message_text' => 'Somebody else\'s private conversation.']);

        $this->file(['subject_type' => 'message', 'subject_id' => $private->id])->assertCreated();

        // Not in the reporter's thread, so only the profile is kept.
        $this->assertSame('Profile', Report::firstOrFail()->snapshot['kind']);
    }

    #[Test]
    public function photos_are_kept_on_the_private_disk(): void
    {
        Storage::fake(config('filesystems.documents'));

        $this->file(['photos' => [
            UploadedFile::fake()->create('one.jpg', 120, 'image/jpeg'),
            UploadedFile::fake()->create('two.png', 120, 'image/png'),
        ]])->assertCreated();

        $evidence = Report::firstOrFail()->evidence;
        $this->assertCount(2, $evidence);
        Storage::disk(config('filesystems.documents'))->assertExists($evidence[0]);
    }

    #[Test]
    public function the_new_report_types_keep_their_own_content(): void
    {
        $post = \App\Models\CommunityPost::create(['user_id' => $this->reporter->id, 'type' => 'employer', 'title' => 'Need a plumber', 'body' => 'Sink leaks.', 'status' => 'live', 'expires_at' => now()->addDays(3)]);
        $comment = \App\Models\CommunityComment::create(['community_post_id' => $post->id, 'user_id' => $this->reported->id,
            'body' => 'Message me on another app, I am cheaper.', 'status' => 'live']);

        $this->file(['subject_type' => 'community_comment', 'subject_id' => $comment->id])->assertCreated();
        $report = Report::latest('id')->firstOrFail();
        $this->assertSame('Community Comment', $report->typeLabel());
        $this->assertSame('Message me on another app, I am cheaper.', $report->snapshot['text']);

        // A review: only one written about the reporter, by the person reported.
        $job = \App\Models\JobPost::create(['employer_id' => $this->reported->id, 'title' => 'Fix the sink', 'description' => 'x', 'status' => 'completed']);
        $review = \App\Models\Review::create(['reviewer_id' => $this->reported->id, 'reviewee_id' => $this->reporter->id, 'job_id' => $job->id,
            'reviewee_role' => 'worker', 'rating' => 1, 'comment' => 'Worst worker ever, never hire.']);
        $this->file(['subject_type' => 'review', 'subject_id' => $review->id, 'reason_code' => 'fake_review'])->assertCreated();
        $this->assertSame('Review', Report::latest('id')->firstOrFail()->snapshot['kind']);
    }

    #[Test]
    public function the_admin_page_shows_the_evidence_and_the_type(): void
    {
        $this->file()->assertCreated();
        $report = Report::firstOrFail();

        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)->get("/admin/reports/{$report->id}")
            ->assertOk()
            ->assertSee('Account')
            ->assertSee('Reported Content')
            ->assertSee('Juan Dela Cruz');
        $this->actingAs($admin)->get('/admin/reports?type=user')->assertOk()->assertSee('Juan Dela Cruz');
        $this->actingAs($admin)->get('/admin/reports?type=review')->assertOk()->assertDontSee('Juan Dela Cruz');
    }

    #[Test]
    public function the_reporter_hears_the_outcome_in_fixed_words(): void
    {
        $this->file()->assertCreated();
        $report = Report::firstOrFail();
        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", [
            'decision' => 'violation', 'reason_code' => 'spam',
        ])->assertRedirect();

        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $this->reporter->id, 'type' => 'report.decided',
            'body' => 'We reviewed your report and took action.',
        ]);
        $this->assertSame(1, UserNotification::where('user_id', $this->reported->id)->where('type', 'moderation.warning')->count());
    }
}
