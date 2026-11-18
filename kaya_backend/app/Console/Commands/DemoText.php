<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/*
    Puts the written sample text on the sample accounts.

    The first population reused a short list of lines everywhere, so the
    same chat line, review and board post showed on dozens of accounts, and
    job and board photos were stock pictures that were not of anyone's work.
    database/demo/sample-text.json holds text written for each row - its own
    trade, place and outcome - and this writes it in. Photos and the face
    pictures used as company logos come off. Only rows belonging to accounts
    on the given domain are touched.

        php artisan kaya:demo-text sample.kaya.test
*/
class DemoText extends Command
{
    protected $signature = 'kaya:demo-text {domain : email domain of the sample accounts} {--file=database/demo/sample-text.json}';

    protected $description = 'Write the sample text onto the sample accounts';

    public function handle(): int
    {
        $domain = ltrim((string) $this->argument('domain'), '@');
        $file = base_path((string) $this->option('file'));
        $text = is_file($file) ? json_decode((string) file_get_contents($file), true) : null;
        if (! is_array($text)) {
            $this->error("Cannot read $file.");

            return self::FAILURE;
        }

        $ids = DB::table('users')->where('email', 'like', '%@' . $domain)->pluck('id', 'email');
        if ($ids->isEmpty()) {
            $this->error("No accounts on $domain.");

            return self::FAILURE;
        }
        $mine = $ids->values()->all();
        $count = array_fill_keys(['jobs', 'messages', 'reviews', 'posts', 'comments', 'bios', 'companies', 'reports', 'appeals'], 0);

        DB::transaction(function () use ($text, $ids, $mine, &$count) {
            // Fields no app screen collects, set through the API. Here too because
            // kaya:demo-finish runs once and the live run predates its cleanup.
            DB::table('worker_profiles')->whereIn('user_id', $mine)->update([
                'rate_min' => null, 'rate_max' => null, 'rate_unit' => 'day', 'rate_by_agreement' => false,
                'available_days' => null, 'travel_km' => null,
            ]);
            DB::table('worker_skills_new')->whereIn('user_id', $mine)->update(['proficiency_level' => null, 'years_of_experience' => null]);
            DB::table('worker_experiences')->whereIn('user_id', $mine)->delete();
            DB::table('jobs_posts')->whereIn('employer_id', $mine)->update(['budget_max' => null]);

            foreach ($text['jobs'] ?? [] as $id => $t) {
                $job = DB::table('jobs_posts')->where('id', $id)->whereIn('employer_id', $mine)->first();
                if (! $job) {
                    continue;
                }
                $hired = DB::table('applications')->where('job_id', $id)->whereNotIn('status', ['pending', 'rejected', 'withdrawn'])->exists();
                DB::table('jobs_posts')->where('id', $id)->update([
                    'title' => $t['title'], 'description' => $t['description'],
                    'budget_period' => $t['budget_period'], 'budget_min' => $t['budget'], 'budget_max' => null,
                    'workers_needed' => $hired ? 1 : max(1, min(20, (int) $t['workers_needed'])),
                    'photos' => null,
                ]);
                $count['jobs']++;

                $threads = DB::table('conversations')->where('job_id', $id)->pluck('id');
                $chat = array_values($t['chat'] ?? []);
                $lines = [$job->employer_id => array_values(array_filter($chat, fn ($k) => $k % 2 === 1, ARRAY_FILTER_USE_KEY))];
                $workerLines = array_values(array_filter($chat, fn ($k) => $k % 2 === 0, ARRAY_FILTER_USE_KEY));
                foreach ($threads as $thread) {
                    $next = [];
                    $messages = DB::table('messages')->where('conversation_id', $thread)
                        ->where(fn ($q) => $q->whereNull('type')->orWhere('type', '!=', 'system'))->orderBy('id')->get(['id', 'sender_id']);
                    foreach ($messages as $m) {
                        $pool = $lines[$m->sender_id] ?? $workerLines;
                        $i = $next[$m->sender_id] = ($next[$m->sender_id] ?? -1) + 1;
                        if (isset($pool[$i])) {
                            DB::table('messages')->where('id', $m->id)->update(['message_text' => $pool[$i]]);
                            $count['messages']++;
                        }
                    }
                    DB::table('schedule_proposals')->where('conversation_id', $thread)->update([
                        'note' => $t['schedule_note'] ?? null,
                        // The pay for the agreed day; an hourly job's day total was never stated, so none.
                        'pay_centavos' => $t['budget_period'] === 'hourly' ? null : (int) $t['budget'] * 100,
                    ]);
                }

                foreach (DB::table('reviews')->where('job_id', $id)->get(['id', 'reviewer_id', 'rating']) as $r) {
                    $comment = $r->reviewer_id == $job->employer_id
                        ? ($r->rating >= 4 ? $t['review_by_employer_good'] : $t['review_by_employer_ok'])
                        : $t['review_by_worker'];
                    if ($comment) {
                        DB::table('reviews')->where('id', $r->id)->update(['comment' => $comment]);
                        $count['reviews']++;
                    }
                }
            }

            foreach ($text['posts'] ?? [] as $id => $t) {
                if (! DB::table('community_posts')->where('id', $id)->whereIn('user_id', $mine)->update(
                    ['title' => $t['title'], 'body' => $t['body'], 'photo_path' => null, 'photo_paths' => null])) {
                    continue;
                }
                $count['posts']++;
                $comments = DB::table('community_comments')->where('community_post_id', $id)->whereIn('user_id', $mine)->orderBy('id')->pluck('id');
                foreach ($comments as $i => $cid) {
                    if (isset($t['comments'][$i])) {
                        DB::table('community_comments')->where('id', $cid)->update(['body' => $t['comments'][$i]]);
                        $count['comments']++;
                    }
                }
            }

            foreach ($text['bios'] ?? [] as $email => $bio) {
                if ($id = $ids[$email] ?? null) {
                    $count['bios'] += DB::table('worker_profiles')->where('user_id', $id)->update(['bio' => $bio]);
                }
            }
            foreach ($text['companies'] ?? [] as $email => $c) {
                if ($id = $ids[$email] ?? null) {
                    // A person's photo is not a business's logo; none until the business adds one.
                    $count['companies'] += DB::table('employer_profiles')->where('user_id', $id)->where('employer_type', 'company')
                        ->update(['industry' => $c['industry'], 'description' => $c['description'], 'image_path' => null, 'logo_path' => null]);
                }
            }
            foreach ($text['reports'] ?? [] as $id => $desc) {
                $count['reports'] += DB::table('reports')->where('id', $id)->whereIn('reporter_id', $mine)->update(['description' => $desc]);
            }
            foreach ($text['appeals'] ?? [] as $id => $appeal) {
                $count['appeals'] += DB::table('strikes')->where('id', $id)->whereIn('user_id', $mine)->whereNotNull('appeal')->update(['appeal' => $appeal]);
            }
        });

        $this->info(collect($count)->map(fn ($n, $k) => "$n $k")->implode(', ') . '.');

        return self::SUCCESS;
    }
}
