<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Review;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Removes everything scenarios:seed created, and nothing else.
 *
 * Scoped by the @scenario.kaya.local address rather than by "recently
 * created" — a time window would eventually take a real testing account with
 * it, and this runs often enough that it has to be unable to.
 */
class ClearScenarios extends Command
{
    protected $signature = 'scenarios:clear';
    protected $description = 'Remove every account and record made by scenarios:seed';

    public function handle(): int
    {
        $ids = User::where('email', 'like', '%@scenario.kaya.local')->pluck('id');

        if ($ids->isEmpty()) {
            $this->line('  Nothing to remove.');

            return self::SUCCESS;
        }

        $jobs = JobPost::whereIn('employer_id', $ids)->pluck('id');
        $applications = Application::whereIn('job_id', $jobs)
            ->orWhereIn('worker_id', $ids)
            ->pluck('id');

        $sessions = DB::table('job_tracking_sessions')
            ->whereIn('application_id', $applications)->pluck('id');

        if ($sessions->isNotEmpty()) {
            DB::table('job_location_pings')->whereIn('tracking_session_id', $sessions)->delete();
            DB::table('job_tracking_sessions')->whereIn('id', $sessions)->delete();
        }

        $conversations = Conversation::whereIn('job_id', $jobs)
            ->orWhereIn('worker_id', $ids)
            ->orWhereIn('employer_id', $ids)
            ->pluck('id');

        Message::whereIn('conversation_id', $conversations)->delete();
        Conversation::whereIn('id', $conversations)->delete();

        Review::whereIn('job_id', $jobs)->orWhereIn('reviewer_id', $ids)->delete();
        Invitation::whereIn('job_id', $jobs)->orWhereIn('worker_id', $ids)->delete();
        Application::whereIn('id', $applications)->delete();

        // saved_jobs keys the saver as worker_id, not user_id.
        DB::table('saved_jobs')->whereIn('job_id', $jobs)->orWhereIn('worker_id', $ids)->delete();
        DB::table('profile_views')->whereIn('viewer_id', $ids)->orWhereIn('viewed_id', $ids)->delete();
        DB::table('worker_skills_new')->whereIn('user_id', $ids)->delete();

        UserNotification::whereIn('user_id', $ids)->delete();
        JobPost::whereIn('id', $jobs)->delete();
        WorkerProfile::whereIn('user_id', $ids)->delete();
        EmployerProfile::whereIn('user_id', $ids)->delete();

        DB::table('personal_access_tokens')
            ->where('tokenable_type', User::class)
            ->whereIn('tokenable_id', $ids)
            ->delete();

        User::whereIn('id', $ids)->delete();

        $this->line("  Removed {$ids->count()} scenario accounts and their records.");

        return self::SUCCESS;
    }
}
