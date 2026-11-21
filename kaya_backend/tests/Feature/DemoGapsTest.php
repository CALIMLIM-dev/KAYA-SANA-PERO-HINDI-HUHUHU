<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DemoGapsTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_kind_real_users_have_and_the_demo_lacks_is_flagged(): void
    {
        $real = User::factory()->create(['email' => 'ana@gmail.com']);
        $sample = User::factory()->create(['email' => 'ben@sample.kaya.test']);
        $other = User::factory()->create(['email' => 'cy@gmail.com']);

        // A real person reported a review; the sample accounts only ever reported profiles.
        DB::table('reports')->insert([
            ['reporter_id' => $real->id, 'reported_id' => $other->id, 'reported_type' => 'review', 'reason' => 'x', 'status' => 'pending', 'created_at' => now(), 'updated_at' => now()],
            ['reporter_id' => $real->id, 'reported_id' => $other->id, 'reported_type' => 'profile', 'reason' => 'x', 'status' => 'pending', 'created_at' => now(), 'updated_at' => now()],
            ['reporter_id' => $sample->id, 'reported_id' => $other->id, 'reported_type' => 'profile', 'reason' => 'x', 'status' => 'pending', 'created_at' => now(), 'updated_at' => now()],
        ]);

        Artisan::call('kaya:demo-gaps', ['domain' => 'sample.kaya.test']);
        $out = Artisan::output();

        $this->assertStringContainsString('reported_type = review', $out);
        $this->assertStringContainsString('MISSING IN DEMO', $out);
        $this->assertStringNotContainsString('reported_type = profile', $out, 'both sides have profile reports');
    }
}
