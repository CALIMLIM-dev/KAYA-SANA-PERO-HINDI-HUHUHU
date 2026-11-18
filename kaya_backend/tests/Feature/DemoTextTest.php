<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DemoTextTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function sample_rows_get_their_own_text_and_lose_stock_photos(): void
    {
        $e = User::factory()->create(['email' => 'ana.reyes1@sample.kaya.test']);
        $w = User::factory()->create(['email' => 'ben.santos2@sample.kaya.test']);
        $c = User::factory()->create(['email' => 'cruz.trading3@sample.kaya.test']);
        $real = User::factory()->create(['email' => 'real@gmail.com']);
        $now = ['created_at' => now(), 'updated_at' => now()];

        $job = DB::table('jobs_posts')->insertGetId(['employer_id' => $e->id, 'title' => 'Old', 'description' => 'Old', 'status' => 'completed',
            'budget_min' => 500, 'budget_max' => 700, 'budget_period' => 'daily', 'workers_needed' => 1, 'photos' => '["a.jpg"]'] + $now);
        $realJob = DB::table('jobs_posts')->insertGetId(['employer_id' => $real->id, 'title' => 'Mine', 'description' => 'Mine', 'status' => 'open', 'workers_needed' => 1] + $now);
        DB::table('applications')->insert(['job_id' => $job, 'worker_id' => $w->id, 'status' => 'completed'] + $now);
        $conv = DB::table('conversations')->insertGetId(['job_id' => $job, 'employer_id' => $e->id, 'worker_id' => $w->id] + $now);
        foreach ([$w, $e, $w] as $by) {
            DB::table('messages')->insert(['conversation_id' => $conv, 'sender_id' => $by->id, 'message_text' => 'same line'] + $now);
        }
        DB::table('messages')->insert(['conversation_id' => $conv, 'sender_id' => $e->id, 'message_text' => 'Schedule set', 'type' => 'system'] + $now);
        DB::table('schedule_proposals')->insert(['conversation_id' => $conv, 'job_id' => $job, 'proposed_by' => $e->id, 'scheduled_date' => now()->toDateString(), 'note' => 'same', 'pay_centavos' => 50000] + $now);
        DB::table('reviews')->insert([['reviewer_id' => $e->id, 'reviewee_id' => $w->id, 'job_id' => $job, 'rating' => 3, 'comment' => 'same'] + $now,
            ['reviewer_id' => $w->id, 'reviewee_id' => $e->id, 'job_id' => $job, 'rating' => 5, 'comment' => 'same'] + $now]);
        $post = DB::table('community_posts')->insertGetId(['user_id' => $w->id, 'type' => 'worker', 'title' => 'Tubero (Urdaneta)', 'body' => 'x', 'photo_path' => 'p.jpg', 'status' => 'live'] + $now);
        DB::table('community_comments')->insert(['community_post_id' => $post, 'user_id' => $e->id, 'body' => 'Available pa po ba?'] + $now);
        DB::table('worker_profiles')->insert(['user_id' => $w->id, 'bio' => 'same bio', 'rate_min' => 500, 'travel_km' => 25] + $now);
        DB::table('worker_skills_new')->insert(['user_id' => $w->id, 'skill_name' => 'Pipe Repair', 'proficiency_level' => 'advanced', 'years_of_experience' => 6] + $now);
        DB::table('employer_profiles')->insert(['user_id' => $c->id, 'employer_type' => 'company', 'industry' => 'Construction', 'description' => 'same', 'image_path' => 'face.jpg'] + $now);

        $file = 'storage/framework/testing-sample-text.json';
        file_put_contents(base_path($file), json_encode([
            'jobs' => [$job => ['title' => 'Tagas sa lababo', 'description' => 'Tumutulo ang tubo.', 'budget_period' => 'project', 'budget' => 900, 'workers_needed' => 3,
                'chat' => ['W1', 'E1', 'W2', 'E2'], 'schedule_note' => 'Sa likod ang kusina.', 'review_by_employer_good' => 'Good', 'review_by_employer_ok' => 'Okay lang', 'review_by_worker' => 'Mabait'],
                $realJob => ['title' => 'Hacked', 'description' => 'x', 'budget_period' => 'daily', 'budget' => 1, 'workers_needed' => 1, 'chat' => []]],
            'posts' => [$post => ['title' => 'Tubero sa bayan', 'body' => 'Bago', 'comments' => ['Saan po kayo banda?']]],
            'bios' => ['ben.santos2@sample.kaya.test' => 'Bagong bio', 'real@gmail.com' => 'Hacked'],
            'companies' => ['cruz.trading3@sample.kaya.test' => ['industry' => 'Hardware Retail', 'description' => 'Tindahan']],
        ]));

        $this->artisan('kaya:demo-text', ['domain' => 'sample.kaya.test', '--file' => $file])->assertSuccessful();
        unlink(base_path($file));

        $j = DB::table('jobs_posts')->find($job);
        $this->assertSame(['Tagas sa lababo', 'project', 900.0, null, 1, null], [$j->title, $j->budget_period, (float) $j->budget_min, $j->budget_max, (int) $j->workers_needed, $j->photos],
            'a hired job keeps one worker');
        $this->assertSame('Mine', DB::table('jobs_posts')->find($realJob)->title, 'a real account is never touched');
        $this->assertSame(['W1', 'E1', 'W2', 'Schedule set'], DB::table('messages')->where('conversation_id', $conv)->orderBy('id')->pluck('message_text')->all());
        $s = DB::table('schedule_proposals')->first();
        $this->assertSame(['Sa likod ang kusina.', 90000], [$s->note, (int) $s->pay_centavos]);
        $this->assertEqualsCanonicalizing(['Okay lang', 'Mabait'], DB::table('reviews')->pluck('comment')->all(), 'the text fits the stars');
        $p = DB::table('community_posts')->find($post);
        $this->assertSame(['Tubero sa bayan', null], [$p->title, $p->photo_path]);
        $this->assertSame('Saan po kayo banda?', DB::table('community_comments')->value('body'));
        $wp = DB::table('worker_profiles')->where('user_id', $w->id)->first();
        $this->assertSame(['Bagong bio', null, null], [$wp->bio, $wp->rate_min, $wp->travel_km]);
        $sk = DB::table('worker_skills_new')->where('user_id', $w->id)->first();
        $this->assertSame([null, null], [$sk->proficiency_level, $sk->years_of_experience], 'no level or years nobody typed');
        $co = DB::table('employer_profiles')->where('user_id', $c->id)->first();
        $this->assertSame(['Hardware Retail', null], [$co->industry, $co->image_path]);
    }
}
