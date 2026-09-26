<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\MessageFilter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What the chat will and will not carry.

    The half that matters most is the second one: every message here that a
    plumber and a homeowner would actually send has to arrive untouched. A
    filter that bounces "ang budget ko 1500 tapos 2000" is worse than no
    filter, because the people it stops are the ones using the app properly
    and the ones it is aimed at simply write it another way.
*/
class MessageFilterTest extends TestCase
{
    use RefreshDatabase;

    private function filter(): MessageFilter
    {
        return app(MessageFilter::class);
    }

    #[Test]
    public function contact_details_are_refused_however_they_are_written(): void
    {
        foreach ([
            'text mo na lang ako sa 0917 123 4567',
            'CP no ko 09171234567 po',
            '+63 917 123 4567 salamat',
            '0917-123-4567',
            // Typed as words precisely to get past a digit check.
            'zero nine one seven one two three four five six seven',
            'juandelacruz@gmail.com',
            'juandelacruz at gmail dot com',
        ] as $text) {
            $this->assertNotNull(
                $this->filter()->contactReason($text),
                "should have been refused: {$text}",
            );
        }
    }

    #[Test]
    public function moving_the_conversation_elsewhere_is_refused(): void
    {
        foreach ([
            'add mo ako sa fb',
            'viber na lang po',
            'pm mo ako',
            'txt mo nlng aq',
            'wag na dito sa app',
            'sa labas na lang tayo',
            // Naming the app by its colour is the oldest way round a filter.
            'message mo ako sa blue app',
            'sa yellow app na lang tayo',
            // Padding and leetspeak.
            'aDd Mo AkO sA f b',
        ] as $text) {
            $this->assertNotNull(
                $this->filter()->contactReason($text),
                "should have been refused: {$text}",
            );
        }
    }

    #[Test]
    public function ordinary_messages_are_left_completely_alone(): void
    {
        foreach ([
            'Pwede po ba bukas ng umaga?',
            'Ang budget ko 1500 tapos 2000 at 3000 para sa tatlong araw',
            // KAYA never holds the job payment, so arranging it is the
            // normal thing and must never be stopped.
            'GCash na lang po ang bayad, salamat',
            'Maya or cash pagkatapos ng trabaho',
            'Nasa Barangay Nancayasan po ako, 5 minutes lang',
            'Sige po, 8 AM bukas. Dalhin ko gamit ko.',
            'Order po ng leche flan at 50 pieces',
            'Tapos na po ang 2 units kahapon',
            'May 10 years experience po ako sa tiling',
        ] as $text) {
            $read = $this->filter()->inspect($text);

            $this->assertNull($read['refusal'], "should have gone through: {$text}");
            $this->assertSame($text, $read['text'], "should not have been touched: {$text}");
        }
    }

    #[Test]
    public function swearing_is_masked_and_still_delivered(): void
    {
        foreach ([
            'gago ka ba',
            'g@gooo ka talaga',
            'putang ina mo',
            'tangina naman o',
            'what the fuck is this',
        ] as $text) {
            $read = $this->filter()->inspect($text);

            $this->assertNull($read['refusal'], "swearing is not a reason to bounce it: {$text}");
            $this->assertTrue($read['masked'], "should have been masked: {$text}");
            $this->assertStringContainsString('*', $read['text']);
        }
    }

    #[Test]
    public function the_chat_endpoint_applies_both_rules(): void
    {
        $employer = User::factory()->create(['is_verified' => true, 'name' => 'Ana Reyes']);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $employer->id], ['balance' => 100]);

        $worker = User::factory()->create(['is_verified' => true, 'name' => 'Ben Santos']);
        WorkerProfile::create(['user_id' => $worker->id, 'location' => 'x']);

        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Paint a fence', 'description' => 'x',
            'status' => 'in_progress', 'workers_needed' => 1,
            'start_date' => now()->addDays(3)->toDateString(),
            'end_date' => now()->addDays(5)->toDateString(),
        ]);

        Application::create([
            'job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted',
        ]);

        $thread = Conversation::create([
            'job_id' => $job->id, 'employer_id' => $employer->id,
            'worker_id' => $worker->id, 'status' => 'unlocked',
        ]);

        $send = fn (string $text) => $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$thread->id}/messages", ['message_text' => $text]);

        /*
            Masked, not refused.

            Bouncing the message taught people to retype the number with a
            space in it and left the conversation stalled over a rule they
            could not see. It goes, with the number taken out of it.
        */
        $send('Sir, text mo ako sa 09171234567')->assertCreated();

        $stored = (string) $thread->messages()->latest('id')->value('message_text');

        $this->assertStringNotContainsString('09171234567', $stored);
        $this->assertStringContainsString('*', $stored);

        $send('gago naman yung kasama ko kahapon')->assertCreated();

        $this->assertStringNotContainsString(
            'gago',
            (string) $thread->messages()->latest('id')->value('message_text'),
        );

        $send('Pwede po bukas ng 8 AM, ₱1500 per day?')->assertCreated();

        $this->assertSame(
            'Pwede po bukas ng 8 AM, ₱1500 per day?',
            (string) $thread->messages()->latest('id')->value('message_text'),
        );
    }
}
