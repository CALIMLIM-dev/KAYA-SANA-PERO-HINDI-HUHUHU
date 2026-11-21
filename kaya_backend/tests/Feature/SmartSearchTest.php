<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Skill;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Searching the way people type: a word at a time, across the category
    and skills as well as the title, and surviving a misspelling.
*/
class SmartSearchTest extends TestCase
{
    use RefreshDatabase;

    private function jobTitled(string $title, ?Category $category = null): JobPost
    {
        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);

        return JobPost::create([
            'employer_id' => $employer->id, 'title' => $title, 'description' => 'Work to be done.',
            'status' => 'open', 'category_id' => $category?->id,
            'start_date' => now()->addDay()->toDateString(), 'end_date' => now()->addDays(3)->toDateString(),
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);
    }

    private function search(User $as, string $term): array
    {
        return $this->actingAs($as, 'sanctum')
            ->getJson('/api/v1/jobs?search=' . urlencode($term))
            ->assertOk()
            ->json('data.data');
    }

    #[Test]
    public function a_misspelling_still_finds_the_job(): void
    {
        $this->jobTitled('Carpentry work needed');
        $viewer = User::factory()->create(['is_verified' => true]);

        $this->assertCount(1, $this->search($viewer, 'carpentry'));
        $this->assertCount(1, $this->search($viewer, 'carpentrey'));
        $this->assertCount(1, $this->search($viewer, 'carpentr'));
    }

    #[Test]
    public function the_category_is_searched_not_only_the_title(): void
    {
        $category = Category::create(['name' => 'Electrical', 'is_active' => true]);
        $this->jobTitled('Fix the lights upstairs', $category);
        $viewer = User::factory()->create(['is_verified' => true]);

        $this->assertCount(1, $this->search($viewer, 'electrical'));
        $this->assertCount(1, $this->search($viewer, 'electrisian'));
    }

    #[Test]
    public function extra_words_and_word_order_do_not_matter(): void
    {
        $this->jobTitled('Mason needed for a two storey build');
        $viewer = User::factory()->create(['is_verified' => true]);

        $this->assertCount(1, $this->search($viewer, 'storey mason'));
        $this->assertCount(1, $this->search($viewer, 'mason urgent today'));
    }

    #[Test]
    public function something_unrelated_still_finds_nothing(): void
    {
        $this->jobTitled('Carpentry work needed');
        $viewer = User::factory()->create(['is_verified' => true]);

        $this->assertCount(0, $this->search($viewer, 'zumba'));
    }

    #[Test]
    public function the_worker_directory_searches_the_same_way(): void
    {
        $category = Category::create(['name' => 'Plumbing', 'is_active' => true]);
        $worker = User::factory()->create(['is_verified' => true, 'name' => 'Ricardo Dela Cruz']);
        WorkerProfile::create(['user_id' => $worker->id, 'location' => 'Urdaneta City', 'category_id' => $category->id,
            'latitude' => 15.9761, 'longitude' => 120.5711,
            'profile_photo_path' => 'worker_photos/seeded.jpg', 'rate_by_agreement' => true,
            'available_days' => [1, 2, 3, 4, 5, 6, 7], 'travel_km' => 100]);
        $skill = Skill::firstOrCreate(['name' => 'Pipe fitting'], ['category_id' => $category->id]);
        WorkerSkill::create(['user_id' => $worker->id, 'skill_id' => $skill->id, 'skill_name' => 'Pipe fitting', 'years_of_experience' => 2]);

        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);

        $rows = fn (string $q) => $this->actingAs($employer, 'sanctum')
            ->getJson('/api/v1/workers?q=' . urlencode($q))
            ->assertOk()
            ->json('data.data');

        $this->assertCount(1, $rows('plumbing'));
        $this->assertCount(1, $rows('plumbng'));
        $this->assertCount(1, $rows('ricardo'));
    }

    #[Test]
    public function a_typed_name_puts_that_person_first_even_with_a_typo(): void
    {
        $category = Category::create(['name' => 'Plumbing', 'is_active' => true]);
        $skill = Skill::firstOrCreate(['name' => 'Pipe fitting'], ['category_id' => $category->id]);
        $make = function (string $name, string $bio, float $lat) use ($category, $skill) {
            $u = User::factory()->create(['is_verified' => true, 'name' => $name]);
            WorkerProfile::create(['user_id' => $u->id, 'location' => 'Urdaneta City', 'category_id' => $category->id,
                'latitude' => $lat, 'longitude' => 120.5711, 'bio' => $bio,
                'profile_photo_path' => 'worker_photos/seeded.jpg', 'rate_by_agreement' => true,
                'available_days' => [1, 2, 3, 4, 5, 6, 7], 'travel_km' => 100]);
            WorkerSkill::create(['user_id' => $u->id, 'skill_id' => $skill->id, 'skill_name' => 'Pipe fitting', 'years_of_experience' => 2]);
            return $u;
        };
        // A stranger whose bio shares a word, and who is newer and nearer.
        $make('Eddison Joed Calimlim', 'Tubero sa Urdaneta.', 15.9761);
        $make('Joed Ramos', 'Kaibigan ni Eddison, tubero din.', 15.9762);

        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        $first = fn (string $q) => $this->actingAs($employer, 'sanctum')
            ->getJson('/api/v1/workers?q=' . urlencode($q))
            ->assertOk()
            ->json('data.data.0.name') ?? $this->actingAs($employer, 'sanctum')
            ->getJson('/api/v1/workers?q=' . urlencode($q))->json('data.data.0.user.name');

        $this->assertSame('Eddison Joed Calimlim', $first('Eddison Joed Calimlim'));
        $this->assertSame('Eddison Joed Calimlim', $first('Edison Calimlim'));
        $this->assertSame('Eddison Joed Calimlim', $first('eddison calimlem'));
    }
}
