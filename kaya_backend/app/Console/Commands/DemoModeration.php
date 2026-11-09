<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Category;
use App\Models\CommunityComment;
use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Report;
use App\Models\Review;
use App\Models\Strike;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\ReportDecisionService;
use App\Services\StrikeService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/*
    Sample accounts for Reports and Appeals & Bans, for the final defense.

    In two stages around a script run from outside, because photos can only
    be saved by the web server: `seed` makes the people, jobs, chats and
    community posts; the script signs in as them through the app's own API
    to add faces, completion photos and the reports with their evidence;
    `decide` then gives the decisions, violations, suspensions, bans and
    appeals. Every account is marked is_demo.
*/
class DemoModeration extends Command
{
    protected $signature = 'kaya:demo-moderation {stage : seed or decide} {--password= : sign-in password for the sample accounts (seed)}';

    protected $description = 'Sample accounts for Reports and Appeals & Bans (seed, then decide)';

    public const DOMAIN = 'kaya-demo.test';

    /** key => [first, last, worker?, employer?, barangay] */
    private const PEOPLE = [
        'maria'  => ['Maria', 'Santos', false, true, 'Poblacion'],
        'jose'   => ['Jose', 'Ramos', true, false, 'San Vicente'],
        'ana'    => ['Ana', 'Villanueva', true, false, 'Nancayasan'],
        'ramon'  => ['Ramon', 'Dizon', false, true, 'Anonas'],
        'liza'   => ['Liza', 'Mendoza', false, true, 'Camantiles'],
        'mark'   => ['Mark', 'Bautista', false, true, 'Bayaoas'],
        'kevin'  => ['Kevin', 'Flores', true, false, 'Cabuloan'],
        'joel'   => ['Joel', 'Garcia', true, false, 'Palina East'],
        'carlo'  => ['Carlo', 'Reyes', true, false, 'Pinmaludpod'],
        'rhea'   => ['Rhea', 'Castillo', true, false, 'Tulong'],
        'paolo'  => ['Paolo', 'Navarro', false, true, 'Sugcong'],
        'grace'  => ['Grace', 'Aquino', false, true, 'San Jose'],
        'nestor' => ['Nestor', 'Pascual', true, false, 'Oltama'],
        'dante'  => ['Dante', 'Cruz', true, true, 'Bactad East'],
    ];

    public static function email(string $key): string
    {
        [$first, $last] = self::PEOPLE[$key];

        return Str::lower("{$first}.{$last}@" . self::DOMAIN);
    }

    public function handle(StrikeService $strikes, ReportDecisionService $decisions): int
    {
        return match ($this->argument('stage')) {
            'seed'   => $this->seed(),
            'decide' => $this->decide($strikes, $decisions),
            default  => tap(self::FAILURE, fn () => $this->error('Stage is seed or decide.')),
        };
    }

    // ── Stage 1 ───────────────────────────────────────────────────────────────

    private function seed(): int
    {
        $password = (string) $this->option('password');
        if (strlen($password) < 8) {
            $this->error('Give --password (8 characters or more) for the sample accounts.');

            return self::FAILURE;
        }
        if (User::where('email', self::email('maria'))->exists()) {
            $this->error('The sample accounts already exist.');

            return self::FAILURE;
        }

        $trade = fn (string $name) => Category::where('name', 'like', "%{$name}%")->value('id')
            ?? Category::where('is_active', true)->value('id');
        $lat = 15.9758;
        $lng = 120.5707;

        DB::transaction(function () use ($password, $trade, $lat, $lng) {
            $u = [];
            foreach (self::PEOPLE as $key => [$first, $last, $worker, $employer, $barangay]) {
                $place = "{$barangay}, Urdaneta City, Pangasinan";
                $user = new User();
                $user->forceFill([
                    'first_name' => $first, 'last_name' => $last, 'name' => "{$first} {$last}",
                    'email' => self::email($key), 'password' => $password, 'is_verified' => true,
                    'email_verified_at' => now(), 'terms_accepted' => true, 'terms_accepted_at' => now(),
                    'is_demo' => true, 'created_at' => now()->subDays(rand(40, 120)),
                ])->save();

                $pin = ['latitude' => $lat + rand(-80, 80) / 10000, 'longitude' => $lng + rand(-80, 80) / 10000];
                if ($worker) {
                    $profile = WorkerProfile::create(['user_id' => $user->id, 'category_id' => $trade($key === 'kevin' ? 'Electric' : 'Plumb'),
                        'location' => $place, 'bio' => 'Maayos at maagap sa trabaho. Taga-Urdaneta.'] + $pin);
                    $profile->forceFill(['availability_status' => 'available'])->save();
                    foreach (['Pipe Repair', 'Leak Repair'] as $skill) {
                        WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $skill, 'category_id' => $profile->category_id, 'years_of_experience' => 3]);
                    }
                }
                if ($employer) {
                    EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => $place] + $pin);
                }
                $u[$key] = $user;
            }

            $job = fn (User $owner, string $title, string $text, string $status, int $startAgo, int $endAgo, int $pay) => JobPost::create([
                'employer_id' => $owner->id, 'category_id' => $trade('Plumb'), 'title' => $title, 'description' => $text,
                'budget_min' => $pay, 'budget_max' => $pay, 'location' => $owner->employerProfile?->location ?? 'Urdaneta City, Pangasinan',
                'city' => 'Urdaneta City', 'status' => $status, 'latitude' => $lat, 'longitude' => $lng, 'workers_needed' => 1,
                'start_date' => now()->subDays($startAgo)->toDateString(), 'end_date' => now()->subDays($endAgo)->toDateString(),
                'expires_at' => now()->addDays(5),
            ]);
            $thread = function (?JobPost $j, User $employer, User $worker, array $lines) {
                $c = Conversation::create(['job_id' => $j?->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id,
                    'pair_low' => min($employer->id, $worker->id), 'pair_high' => max($employer->id, $worker->id), 'status' => 'unlocked']);
                foreach ($lines as $i => [$who, $text]) {
                    $m = Message::create(['conversation_id' => $c->id, 'sender_id' => $who->id, 'message_text' => $text]);
                    $m->forceFill(['created_at' => now()->subHours(count($lines) - $i + 5)])->save();
                }

                return $c;
            };
            $hire = fn (JobPost $j, User $w, string $status = 'accepted') => Application::create(['job_id' => $j->id, 'worker_id' => $w->id, 'status' => $status]);

            // A job Jose took and never came to.
            $sink = $job($u['maria'], 'Ayusin ang tumutulong lababo', 'Tumutulo ang tubo sa ilalim ng lababo sa kusina. Kailangan palitan ang P-trap.', 'in_progress', 3, 1, 900);
            $hire($sink, $u['jose']);
            $thread($sink, $u['maria'], $u['jose'], [[$u['maria'], 'Kuya, 8 AM po bukas ha. Andito lang ako sa bahay.'], [$u['jose'], 'Sige po ma\'am, darating ako.'], [$u['maria'], 'Kuya nasaan na po kayo? 10 AM na.']]);

            // A job Ana finished; Ramon says she did not.
            $faucet = $job($u['ramon'], 'Palitan ang gripo sa banyo', 'Bagong gripo, nabili ko na. Ikabit lang at siguraduhing walang tagas.', 'in_progress', 4, 1, 700);
            $hire($faucet, $u['ana']);
            $thread($faucet, $u['ramon'], $u['ana'], [[$u['ana'], 'Tapos na po sir, wala nang tagas. Pinicturan ko na rin.'], [$u['ramon'], 'Ok.']]);

            // Nestor's job, still being looked at.
            $tank = $job($u['maria'], 'Linisin ang water tank', 'Lumang tangke sa likod ng bahay, kailangan linisin at i-check ang valve.', 'in_progress', 2, 1, 1200);
            $hire($tank, $u['nestor']);

            // Dante: the job post, the chat, the board post, the comment and the review that get reported.
            $job($u['dante'], 'Painter needed, P1,500 a day', 'Pintura ng buong bahay, 3 araw. P1,500 kada araw, may meryenda.', 'open', -2, -6, 1500);
            $chatJob = $job($u['dante'], 'Magkabit ng shower heater', 'Shower heater sa CR, may sariling breaker na.', 'in_progress', 1, -1, 800);
            $hire($chatJob, $u['ana']);
            $thread($chatJob, $u['dante'], $u['ana'], [
                [$u['ana'], 'Sir, P800 po ang napagkasunduan natin, hindi P500.'],
                [$u['dante'], 'Wag kang magreklamo. Pag di ka pumayag sa 500, ipapahiya kita sa lahat ng kakilala ko dito.'],
            ]);
            $reviewJob = $job($u['dante'], 'Ayusin ang kanal sa likod', 'Barado ang kanal, kailangan linisin.', 'completed', 20, 19, 600);
            $hire($reviewJob, $u['rhea'], 'completed')->forceFill(['worker_completed_at' => now()->subDays(19), 'employer_completed_at' => now()->subDays(19)])->save();
            $review = Review::create(['reviewer_id' => $u['dante']->id, 'reviewee_id' => $u['rhea']->id, 'job_id' => $reviewJob->id,
                'reviewee_role' => 'worker', 'rating' => 1, 'comment' => 'Pinakamasamang trabahador. Huwag ninyong kunin, magnanakaw pa.']);
            $review->forceFill(['created_at' => now()->subDays(18)])->save();
            CommunityPost::create(['user_id' => $u['dante']->id, 'type' => 'worker', 'status' => 'live', 'expires_at' => now()->addDays(5),
                'title' => 'MURANG LOAN 5 MINUTES APPROVE', 'body' => 'Kailangan ng pera? Loan agad, walang requirements! I-message ako sa ibang app.']);
            $mariaPost = CommunityPost::create(['user_id' => $u['maria']->id, 'type' => 'employer', 'status' => 'live', 'expires_at' => now()->addDays(4),
                'title' => 'Naghahanap ng tubero sa Poblacion', 'body' => 'May tagas ang tubo sa labas ng bahay. Sino po available ngayong linggo?']);
            CommunityComment::create(['community_post_id' => $mariaPost->id, 'user_id' => $u['dante']->id, 'status' => 'live',
                'body' => 'Ako na lang po, mas mura ako. I-text mo ako sa ibang app, wag dito.']);

            // Mark's scam, in a chat with Maria.
            $thread(null, $u['mark'], $u['maria'], [[$u['mark'], 'Ma\'am, magpadala muna kayo ng P2,000 deposit sa akin bago ko kayo ipadala ng tubero.']]);

            // Grace's joke category.
            Category::create(['name' => 'Tsismis Delivery', 'is_active' => true, 'is_custom' => true, 'created_by' => $u['grace']->id]);

            // A demo moderator to give the decisions; nobody signs in as it.
            $mod = new User();
            $mod->forceFill(['name' => 'Demo Moderator', 'first_name' => 'Demo', 'last_name' => 'Moderator', 'email' => 'moderator@' . self::DOMAIN,
                'password' => Str::random(40), 'user_type' => 'admin', 'is_verified' => true, 'is_demo' => true, 'must_change_password' => true])->save();
            $mod->forceFill(['admin_role' => 'sub_admin'])->save();
        });

        $this->info('Sample accounts made: ' . count(self::PEOPLE) . ' people, all @' . self::DOMAIN . '. Now run the photo and report script, then: php artisan kaya:demo-moderation decide');

        return self::SUCCESS;
    }

    // ── Stage 2 ───────────────────────────────────────────────────────────────

    private function decide(StrikeService $strikes, ReportDecisionService $decisions): int
    {
        $u = collect(array_keys(self::PEOPLE))->mapWithKeys(fn ($k) => [$k => User::where('email', self::email($k))->first()]);
        $mod = User::where('email', 'moderator@' . self::DOMAIN)->first();
        if ($u->contains(null) || ! $mod) {
            $this->error('Run the seed stage first.');

            return self::FAILURE;
        }

        $report = fn (string $from, string $about, string $reason) => Report::where('reporter_id', $u[$from]->id)
            ->where('reported_id', $u[$about]->id)->where('reason_code', $reason)->whereIn('status', ['pending', 'reviewed'])->first();
        $decide = function (string $from, string $about, string $reason, string $decision, ?string $violation = null) use ($report, $decisions, $mod) {
            $r = $report($from, $about, $reason);
            if (! $r) {
                $this->warn("No pending report from {$from} about {$about} ({$reason}); the script may not have filed it.");

                return null;
            }
            $decisions->decide($r, $decision, $violation, $mod, $strike);

            return $strike;
        };
        // Moves a violation back in time, with what it limits.
        $ago = function (?Strike $s, int $days) {
            if (! $s) {
                return;
            }
            $at = now()->subDays($days);
            $s->forceFill([
                'created_at' => $at,
                'expires_at' => $at->copy()->addDays((int) config('moderation.strike_days')),
                'ends_at'    => $s->days ? $at->copy()->addDays($s->days) : null,
            ])->save();
            if ($s->action === 'suspension') {
                $s->user->forceFill(['suspended_until' => $s->ends_at->isFuture() ? $s->ends_at : null,
                    'is_suspended' => $s->ends_at->isFuture()])->save();
            }
        };
        $appeal = function (?Strike $s, string $text, int $daysAgo) {
            $s?->forceFill(['appeal' => $text, 'appealed_at' => now()->subDays($daysAgo), 'appeal_status' => 'pending'])->save();
        };

        // Job problems: the real one and the false one.
        $jose = $decide('maria', 'jose', 'no_show', 'violation', 'no_show');
        $ago($jose, 2);
        $appeal($jose, 'Nagkasakit po ang anak ko noong araw na iyon at sinugod ko sa ospital. Nag-message ako kay ma\'am pero walang signal. May medical certificate po ako.', 1);
        $decide('ramon', 'ana', 'work_not_done', 'false_report');

        // Liza's three false reports in a month: the third brings the warning.
        foreach (['paolo', 'grace', 'nestor'] as $target) {
            $decide('liza', $target, 'harassment', 'false_report');
        }

        // Mark's scam: banned at once, and appealing.
        $mark = $decide('maria', 'mark', 'scam', 'violation', 'fraud');
        $appeal($mark, 'Hindi po ako scammer. Deposit lang po iyon para sa materyales, ibabalik ko naman.', 0);

        // Straight from the account page.
        $kevin = $strikes->issue($u['kevin'], 'fake_documents', $mod);
        $ago($kevin, 6);
        $appeal($kevin, 'Totoo po ang ID ko, malabo lang ang kuha ng camera.', 5);
        $strikes->decideAppeal($kevin->fresh(), $mod, false);

        $ago($strikes->issue($u['joel'], 'spam', $mod), 45);
        $ago($strikes->issue($u['joel'], 'spam', $mod), 25);
        $ago($strikes->issue($u['joel'], 'spam', $mod), 3);

        $ago($strikes->issue($u['carlo'], 'spam', $mod), 25);
        $ago($strikes->issue($u['carlo'], 'inappropriate_content', $mod), 5);

        $ago($strikes->issue($u['rhea'], 'no_show', $mod), 2);

        $paolo = $strikes->issue($u['paolo'], 'misleading_postings', $mod);
        $ago($paolo, 4);
        $appeal($paolo, 'Nagbago po ang presyo ng materyales kaya binago ko ang bayad, pero sinabi ko po agad sa chat bago siya pumunta.', 3);
        $strikes->decideAppeal($paolo->fresh(), $mod, true);

        $strikes->issue($u['grace'], 'category_misuse', $mod);

        $this->info('Decided. Pending reports left for you: ' . Report::whereIn('status', ['pending', 'reviewed'])
            ->whereIn('reported_id', $u->pluck('id'))->count() . '.');

        return self::SUCCESS;
    }
}
