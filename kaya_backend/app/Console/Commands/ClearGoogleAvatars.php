<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

/**
 * Clears profile pictures that came from a Google account.
 *
 * For a while, signing in with Google copied that account's picture straight
 * onto the KAYA profile, and every account created in that window still has it.
 * On a hiring app the photo is what an employer decides on, so it has to be one
 * the worker chose and knows about — not a group shot pulled from Gmail.
 *
 * The signup and login paths no longer do this. This is the one-off that undoes
 * what they already saved: any avatar that is a remote URL (Google's are
 * https://lh3.googleusercontent.com/...) is cleared, and the profile falls back
 * to the default picture until the person uploads their own. Uploaded photos
 * are stored as a path, not a URL, so they are left alone.
 *
 * Nothing is deleted here — no account, no profile, no uploaded file. Only the
 * one column is reset, so it is safe to run on live data, unlike demo:clear.
 */
class ClearGoogleAvatars extends Command
{
    protected $signature = 'users:clear-google-avatars {--force : Skip the confirmation prompt}';

    protected $description = 'Reset any profile picture that is a remote (Google) URL back to the default';

    public function handle(): int
    {
        // A stored upload is a path like "avatars/ab12.jpg"; a Google picture is
        // a full URL. Matching on the scheme is what separates the two.
        $affected = User::where('avatar', 'like', 'http%');
        $count = $affected->count();

        if ($count === 0) {
            $this->info('No Google avatars to clear.');
            return self::SUCCESS;
        }

        if (! $this->option('force')
            && ! $this->confirm("Clear the profile picture on {$count} account(s)?")) {
            $this->info('Nothing changed.');
            return self::SUCCESS;
        }

        // update() rather than loading each model: this is a single column on
        // possibly every account, and there is nothing per-row to decide.
        $affected->update(['avatar' => null]);

        $this->info("Cleared {$count} Google avatar(s). Those profiles now show the default picture.");

        return self::SUCCESS;
    }
}
