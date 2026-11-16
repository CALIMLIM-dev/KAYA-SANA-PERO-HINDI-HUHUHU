<?php

namespace Database\Seeders;

use App\Models\Application;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

/*
    Two people and one hire, for the on-device end-to-end test
    (kaya_app/integration_test/app_e2e_test.dart).

    An employer and a worker, both verified, with an accepted hire and an
    open chat that already holds the worker's first message. The test signs
    in as the employer, answers in the chat, and then blocks the worker.

    Local or test databases only:

        php artisan migrate:fresh --seed
        php artisan db:seed --class=CreditPackageSeeder
        php artisan db:seed --class=E2eSeeder
*/
class E2eSeeder extends Seeder
{
    public const PASSWORD = 'KayaE2e2026!';
    public const EMPLOYER = 'e2e.employer@e2e.kaya.test';
    public const WORKER = 'e2e.worker@e2e.kaya.test';

    public function run(): void
    {
        if (app()->environment('production')) {
            throw new RuntimeException('E2eSeeder never runs in production.');
        }

        $password = Hash::make(self::PASSWORD);
        $trade = Category::firstOrCreate(['name' => 'Painting']);
        // Urdaneta City, Pangasinan.
        [$lat, $lng] = [15.9758, 120.5711];

        $employer = User::factory()->create([
            'name' => 'Ana Reyes', 'email' => self::EMPLOYER, 'password' => $password,
            'is_verified' => true, 'email_verified_at' => now(),
        ]);
        EmployerProfile::create([
            'user_id' => $employer->id, 'employer_type' => 'individual',
            'location' => 'Urdaneta City, Pangasinan', 'setup_completed' => true,
        ]);
        CreditWallet::updateOrCreate(['user_id' => $employer->id], ['balance' => 100]);

        $worker = User::factory()->create([
            'name' => 'Ben Santos', 'email' => self::WORKER, 'password' => $password,
            'is_verified' => true, 'email_verified_at' => now(),
        ]);
        WorkerProfile::create([
            'user_id' => $worker->id, 'category_id' => $trade->id,
            'location' => 'Urdaneta City, Pangasinan', 'latitude' => $lat, 'longitude' => $lng,
        ]);
        WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'House Painting', 'category_id' => $trade->id]);

        $job = JobPost::create([
            'employer_id' => $employer->id, 'category_id' => $trade->id,
            'title' => 'Paint the front gate', 'description' => 'One gate, two coats. Paint is provided.',
            'location' => 'Urdaneta City, Pangasinan', 'latitude' => $lat, 'longitude' => $lng,
            'status' => 'in_progress', 'workers_needed' => 1,
            'end_date' => now()->addDays(5)->toDateString(), 'expires_at' => now()->addDays(5)->endOfDay(),
        ]);
        Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);

        $thread = Conversation::create([
            'pair_low' => min($employer->id, $worker->id), 'pair_high' => max($employer->id, $worker->id),
            'job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id,
            'status' => 'unlocked',
        ]);
        Message::create([
            'conversation_id' => $thread->id, 'sender_id' => $worker->id,
            'message_text' => 'Magandang araw po. Kailan po ako pwedeng magsimula?',
        ]);

        $this->command?->info("E2E: employer {$employer->id}, worker {$worker->id}, thread {$thread->id}.");
    }
}
