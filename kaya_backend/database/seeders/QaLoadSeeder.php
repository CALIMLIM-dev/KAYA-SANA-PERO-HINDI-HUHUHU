<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\CommunityComment;
use App\Models\CommunityPost;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

/*
    Volume for load testing, on a LOCAL or test database only.

    Built from the real columns (the same ones the feature tests and the
    API write): employers with open jobs around Urdaneta, listable workers
    (a trade, a skill and a town), and one community post with a flood of
    comments - the shapes the QA audit's findings 5 and 6 are about.

    Every account is is_demo and uses @load.kaya.test, so it is never
    mistaken for a person and can be found and removed. It refuses to run
    in production: the live site keeps its own demo data.

        php artisan db:seed --class=QaLoadSeeder
        QA_SEED_SCALE=2000 php artisan db:seed --class=QaLoadSeeder

    Every account's password is the one in PASSWORD, for the k6 scripts.
*/
class QaLoadSeeder extends Seeder
{
    public const PASSWORD = 'KayaLoad2026!';

    public function run(): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('QaLoadSeeder never runs in production.');
        }

        $scale = max(1, (int) env('QA_SEED_SCALE', 200));
        $password = Hash::make(self::PASSWORD);
        $trades = ['Electrical', 'Plumbing', 'Masonry', 'Carpentry', 'Painting'];
        $categories = collect($trades)->map(fn ($n) => Category::firstOrCreate(['name' => $n]));

        // Around Urdaneta City, Pangasinan, so distance sorting has work to do.
        $near = fn () => [15.9758 + mt_rand(-300, 300) / 10000, 120.5711 + mt_rand(-300, 300) / 10000];

        $employers = collect(range(1, max(1, intdiv($scale, 10))))->map(function ($i) use ($password) {
            $user = User::factory()->create([
                'name' => "Load Employer {$i}", 'email' => "employer{$i}@load.kaya.test",
                'password' => $password, 'is_verified' => true,
            ]);
            $user->forceFill(['is_demo' => true])->save();
            EmployerProfile::create(['user_id' => $user->id]);

            return $user;
        });

        foreach (range(1, $scale) as $i) {
            [$lat, $lng] = $near();
            $category = $categories[$i % $categories->count()];
            JobPost::create([
                'employer_id' => $employers[$i % $employers->count()]->id,
                'category_id' => $category->id,
                'title' => "{$category->name} work #{$i}",
                'description' => 'Load test job. Two days of work, tools provided.',
                'location' => 'Urdaneta City', 'latitude' => $lat, 'longitude' => $lng,
                'status' => 'open', 'budget_period' => 'daily', 'budget_min' => 800 + ($i % 10) * 50,
                'expires_at' => now()->addDays(7),
            ]);
        }

        foreach (range(1, $scale) as $i) {
            [$lat, $lng] = $near();
            $category = $categories[$i % $categories->count()];
            $user = User::factory()->create([
                'name' => "Load Worker {$i}", 'email' => "worker{$i}@load.kaya.test",
                'password' => $password, 'is_verified' => true,
            ]);
            $user->forceFill(['is_demo' => true])->save();
            WorkerProfile::create([
                'user_id' => $user->id, 'category_id' => $category->id,
                'location' => 'Urdaneta City', 'latitude' => $lat, 'longitude' => $lng,
            ]);
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => "{$category->name} repair", 'category_id' => $category->id]);
        }

        // One flooded post: comments are what finding 6 bounded.
        $poster = $employers->first();
        $post = CommunityPost::create([
            'user_id' => $poster->id, 'type' => CommunityPost::TYPE_EMPLOYER,
            'title' => 'Load test notice', 'body' => 'Hiring painters this week.',
            'status' => CommunityPost::STATUS_LIVE, 'expires_at' => now()->addDays(7),
        ]);
        foreach (range(1, $scale * 2) as $i) {
            CommunityComment::create([
                'community_post_id' => $post->id, 'user_id' => $poster->id,
                'body' => "Comment {$i}", 'status' => CommunityComment::STATUS_LIVE, 'checked_at' => now(),
            ]);
        }

        $this->command?->info("Seeded {$scale} jobs, {$scale} workers, {$employers->count()} employers, " . ($scale * 2) . " comments on post {$post->id}.");
    }
}
