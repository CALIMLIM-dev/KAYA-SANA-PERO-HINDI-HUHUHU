<?php

namespace Database\Seeders;

use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * Demo data for looking at the admin panel.
 *
 * Not part of DatabaseSeeder and never run automatically. Every row it writes
 * is tagged with a demo email domain so it can be removed again in one command:
 *
 *   php artisan db:seed --class=DemoDataSeeder
 *   php artisan demo:clear
 *
 * The point is the reporting screens. Charts of an empty marketplace all render
 * the same empty state, so there is no way to tell a working chart from a broken
 * one until there are rows behind it.
 *
 * Records are spread backwards across 90 days rather than created at once,
 * because every trend on the analytics page is grouped by date — seeded in a
 * single moment they would draw one spike and 89 days of nothing.
 */
class DemoDataSeeder extends Seeder
{
    /** Everything created here uses this domain, which is what makes it removable. */
    public const DOMAIN = 'demo.kaya.local';

    private const WORKERS = [
        'Marilou Bautista', 'Ronaldo Sison', 'Jenny Ramos', 'Arnel Domingo',
        'Cristina Valdez', 'Bernard Aquino', 'Liezl Pascual', 'Danilo Ocampo',
        'Rowena Castillo', 'Efren Mangubat', 'Grace Villanueva', 'Jomar Aguilar',
    ];

    private const EMPLOYERS = [
        'Santos Hardware', 'Urdaneta Fresh Mart', 'Delos Reyes Construction',
        'Bagsit Catering Services', 'CityLine Auto Repair', 'Villamor Farms',
    ];

    private const JOB_TITLES = [
        'Carpenter for kitchen cabinets', 'House painter, two storey',
        'Electrical rewiring', 'Aircon cleaning and servicing',
        'Delivery rider, weekends', 'Kasambahay, live out',
        'Welder for gate fabrication', 'Plumber for bathroom leak',
        'Tile setter, 40 sqm', 'Store helper', 'Motorcycle mechanic',
        'Event waiter, one day', 'Landscaping and grass cutting',
        'Roof repair after typhoon', 'CCTV installation',
        'Massage therapist, home service', 'Laundry attendant',
        'Farm hand for harvest season',
    ];

    private const CITIES = [
        'Urdaneta City', 'Dagupan City', 'San Carlos City',
        'Villasis', 'Binalonan', 'Rosales',
    ];

    public function run(): void
    {
        $categories = DB::table('categories')->pluck('id')->all();
        $skills     = DB::table('skills')->pluck('id')->all();

        if (empty($categories)) {
            $this->command?->error('No categories found. Run the main seeders first.');
            return;
        }

        DB::transaction(function () use ($categories, $skills) {
            $workers   = $this->makeUsers(self::WORKERS, 'worker', $categories);
            $employers = $this->makeUsers(self::EMPLOYERS, 'employer', $categories);

            // Two accounts hold both sides, so the hybrid segment is not empty.
            foreach (array_slice($workers, 0, 2) as $user) {
                $this->employerProfile($user);
            }

            $jobs = $this->makeJobs($employers, $categories, $skills);
            $this->makeApplications($jobs, $workers);
            $this->makeVerifications(array_merge($workers, $employers));
        });

        $this->command?->info('Demo data seeded. Remove it with: php artisan demo:clear');
    }

    /**
     * @param  string[]  $names
     * @return User[]
     */
    private function makeUsers(array $names, string $side, array $categories): array
    {
        $users = [];

        foreach ($names as $i => $name) {
            $slug = str($name)->slug('.')->lower()->toString();

            /*
                Spread across the window so the sign-up trend has a shape.

                Dealt out rather than drawn at random. A uniform random pick
                over 88 days puts only about a third of these inside the 30 day
                chart the analytics page opens on, and occasionally lands the
                survivors on a single day — leaving the sign-up chart as one
                bar, or none, in front of whoever the demo is for. It also made
                the seeder test intermittent, which is worse than a failing
                test because it teaches people to re-run rather than look.

                Alternating between a recent stretch and the older tail keeps
                the long trend interesting while guaranteeing several distinct
                days inside every period the page offers, including the
                shortest.
            */
            $daysAgo = $i % 2 === 0
                ? 1 + ($i % 6)                       // inside even a 7 day view
                : 8 + (($i * 7) % 80);               // the older tail

            $created = Carbon::now()->subDays($daysAgo)
                ->setTime(random_int(7, 20), random_int(0, 59));

            $user = User::create([
                'name'              => $name,
                'email'             => $slug . '@' . self::DOMAIN,
                'password'          => Hash::make('password'),
                'phone'             => '09' . random_int(100000000, 999999999),
                'user_type'         => 'worker',
                'is_verified'       => false,
                'email_verified_at' => $created,
                'created_at'        => $created,
                'updated_at'        => $created,
            ]);

            if ($side === 'worker') {
                $this->workerProfile($user, $categories, $created);
            } else {
                $this->employerProfile($user, $created);
            }

            $users[] = $user;
        }

        return $users;
    }

    private function workerProfile(User $user, array $categories, Carbon $created): void
    {
        $city = self::CITIES[array_rand(self::CITIES)];

        DB::table('worker_profiles')->insert([
            'user_id'      => $user->id,
            'category_id'  => $categories[array_rand($categories)],
            'bio'          => 'Available for work around ' . $city . '.',
            'location'     => $city,
            'rating_avg'   => round(random_int(35, 50) / 10, 1),
            'rating_count' => random_int(0, 24),
            // Counted as a worker by profile existence, but the app also gates
            // several screens on this, so a demo account has to look finished.
            'setup_completed' => true,
            'created_at'      => $created,
            'updated_at'      => $created,
        ]);
    }

    private function employerProfile(User $user, ?Carbon $created = null): void
    {
        $created ??= $user->created_at ?? Carbon::now()->subDays(30);

        $city = self::CITIES[array_rand(self::CITIES)];

        DB::table('employer_profiles')->insert([
            'user_id'         => $user->id,
            'company_name'    => $user->name,
            'employer_type'   => 'company',
            'description'     => 'Hiring locally in ' . $city . '.',
            'location'        => $city,
            'setup_completed' => true,
            'created_at'      => $created,
            'updated_at'      => $created,
        ]);
    }

    /** @return JobPost[] */
    private function makeJobs(array $employers, array $categories, array $skills): array
    {
        $jobs = [];

        // Weighted so the status doughnut is not four equal quarters, which is
        // what a uniform random pick would produce and would look invented.
        $statuses = array_merge(
            array_fill(0, 9, 'open'),
            array_fill(0, 6, 'completed'),
            array_fill(0, 3, 'closed'),
            ['flagged'],
        );

        foreach (self::JOB_TITLES as $title) {
            // Two or three postings each, so categories differ in weight.
            foreach (range(1, random_int(1, 3)) as $ignored) {
                $employer = $employers[array_rand($employers)];
                $created  = Carbon::now()->subDays(random_int(0, 84))->setTime(random_int(8, 19), random_int(0, 59));

                $min = random_int(3, 15) * 100;

                $job = JobPost::create([
                    'employer_id' => $employer->id,
                    'category_id' => $categories[array_rand($categories)],
                    'title'       => $title,
                    'description' => 'Looking for someone reliable. Materials provided. Please message for details.',
                    'budget_min'  => $min,
                    'budget_max'  => $min + random_int(2, 8) * 100,
                    'location'    => self::CITIES[array_rand(self::CITIES)],
                    'city'        => self::CITIES[array_rand(self::CITIES)],
                    'status'      => $statuses[array_rand($statuses)],
                    'created_at'  => $created,
                    'updated_at'  => $created,
                ]);

                $this->attachSkills($job, $skills);

                $jobs[] = $job;
            }
        }

        return $jobs;
    }

    private function attachSkills(JobPost $job, array $skills): void
    {
        if (empty($skills) || ! DB::getSchemaBuilder()->hasTable('job_skills')) {
            return;
        }

        $picked = (array) array_rand(array_flip($skills), min(random_int(1, 3), count($skills)));

        foreach ($picked as $skillId) {
            DB::table('job_skills')->insertOrIgnore([
                'job_id'   => $job->id,
                'skill_id' => $skillId,
            ]);
        }
    }

    private function makeApplications(array $jobs, array $workers): void
    {
        foreach ($jobs as $job) {
            $applicants = (array) array_rand(array_flip(array_keys($workers)), min(random_int(1, 5), count($workers)));
            $accepted   = false;

            foreach ($applicants as $index) {
                $worker = $workers[$index];

                // An application cannot predate the job it answers.
                $applied = Carbon::parse($job->created_at)->addHours(random_int(2, 240));
                if ($applied->isFuture()) {
                    $applied = Carbon::now()->subHours(random_int(1, 12));
                }

                // At most one acceptance per job, and only where the job's own
                // status implies somebody was actually taken on.
                $status = 'pending';
                if (! $accepted && in_array($job->status, ['completed', 'closed'], true)) {
                    $status   = 'accepted';
                    $accepted = true;
                } elseif (random_int(1, 100) <= 18) {
                    $status = 'rejected';
                }

                Application::create([
                    'job_id'     => $job->id,
                    'worker_id'  => $worker->id,
                    'status'     => $status,
                    'created_at' => $applied,
                    'updated_at' => $applied,
                ]);
            }

            $job->update(['application_count' => count($applicants)]);
        }
    }

    private function makeVerifications(array $users): void
    {
        foreach ($users as $user) {
            if (random_int(1, 100) > 70) {
                continue;
            }

            $status = ['verified', 'verified', 'verified', 'pending', 'rejected'][random_int(0, 4)];
            $at     = Carbon::parse($user->created_at)->addDays(random_int(0, 5));

            Verification::create([
                'user_id'          => $user->id,
                'document_type'    => 'government_id',
                'status'           => $status,
                'rejection_reason' => $status === 'rejected' ? 'Photo of the ID was too blurred to read.' : null,
                'created_at'       => $at,
                'updated_at'       => $at,
            ]);

            if ($status === 'verified') {
                $user->update(['is_verified' => true]);
            }
        }
    }
}
