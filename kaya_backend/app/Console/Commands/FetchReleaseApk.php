<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

/*
    Pulls a published APK onto this server so the app can download it here.

    Why this exists: GitHub serves release assets from
    release-assets.githubusercontent.com, and that host is unreachable from at
    least one Philippine network - it accepts the connection and never
    answers, so the in-app updater sat at 0% and eventually failed. github.com
    itself is fine, which is what makes it confusing to diagnose from a
    browser.

    The server has no such problem, so it fetches the file once and nginx
    serves it from this domain - the same host the app already talks to for
    everything else. That also gets range requests and resumable downloads,
    which a redirect to a third party never guaranteed.

    Not committed to git: a 60MB binary per release would bloat the repository
    past what GitHub accepts, and the file is reproducible from the release
    at any time by running this again.
*/
class FetchReleaseApk extends Command
{
    protected $signature = 'kaya:fetch-apk
        {version? : The released version, defaults to APP_LATEST_VERSION}
        {--repo=CALIMLIM-dev/KAYA-SANA-PERO-HINDI-HUHUHU : owner/name of the GitHub repository}';

    protected $description = 'Download a published release APK into public/ so this server can serve it';

    public function handle(): int
    {
        $version = $this->argument('version') ?: config('kaya.app.latest_version');
        $repo = $this->option('repo');

        $url = "https://github.com/{$repo}/releases/download/v{$version}/kaya.apk";

        $this->info("Fetching {$url}");

        $target = public_path('kaya.apk');

        // Written beside the real name and moved into place at the end. A
        // half-finished file at the real path would be served to whoever asked
        // for it in the meantime, and a truncated APK is the "problem parsing
        // the package" error that sends people debugging the wrong thing.
        $temp = $target . '.part';

        try {
            $response = Http::timeout(600)
                ->withOptions(['allow_redirects' => ['max' => 10]])
                ->sink($temp)
                ->get($url);
        } catch (\Throwable $e) {
            @unlink($temp);
            $this->error('Could not reach GitHub: ' . $e->getMessage());

            return self::FAILURE;
        }

        if (! $response->successful()) {
            @unlink($temp);
            $this->error("GitHub answered {$response->status()}. Is v{$version} published with a kaya.apk asset?");

            return self::FAILURE;
        }

        $size = @filesize($temp) ?: 0;

        /*
            An APK is a zip, and a zip starts with PK.

            Checked because the failure mode here is not an error - it is a
            small HTML page saved happily under the name kaya.apk, which the
            installer then rejects as corrupt. Size alone would not catch a
            large error page either.
        */
        $magic = @file_get_contents($temp, false, null, 0, 2);

        if ($size < 5 * 1024 * 1024 || $magic !== 'PK') {
            @unlink($temp);
            $this->error('That download is not an APK (' . number_format($size) . ' bytes). Nothing was replaced.');

            return self::FAILURE;
        }

        if (! @rename($temp, $target)) {
            @unlink($temp);
            $this->error('Could not write ' . $target . ' - check the directory is writable by this user.');

            return self::FAILURE;
        }

        $this->info('Saved ' . number_format($size) . ' bytes to ' . $target);
        $this->newLine();
        $this->line('Point the app at it with:');
        $this->line('  APP_DOWNLOAD_FILE_URL=' . url('/kaya.apk'));

        return self::SUCCESS;
    }
}
