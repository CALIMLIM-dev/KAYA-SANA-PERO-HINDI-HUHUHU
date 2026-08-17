<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Moves already-uploaded verification documents off the public disk.
 *
 * New uploads go to the private disk, but anything submitted before that
 * change is still sitting under `storage/app/public/verifications/`, which the
 * `public/storage` symlink serves to the open internet.
 *
 * Run once. Safe to run again — files already moved are skipped.
 *
 * The files this moves should be treated as **already disclosed**. Moving them
 * stops future access; it cannot un-publish what was reachable. The people they
 * belong to need to be told.
 */
class SecureVerificationDocuments extends Command
{
    protected $signature = 'kaya:secure-verification-documents {--dry-run : List what would move without moving it}';

    protected $description = 'Move verification documents from the public disk to private storage';

    public function handle(): int
    {
        $public = Storage::disk('public');
        $local  = Storage::disk('local');
        $dryRun = $this->option('dry-run');

        $files = collect(['verifications/ids', 'verifications/selfies', 'verifications'])
            ->flatMap(fn ($dir) => $public->exists($dir) ? $public->files($dir) : [])
            ->unique()
            ->values();

        if ($files->isEmpty()) {
            $this->info('Nothing on the public disk. Already secured.');
            return self::SUCCESS;
        }

        $this->warn("{$files->count()} verification file(s) are on the public disk:");
        foreach ($files as $file) {
            $this->line('  ' . $file);
        }

        if ($dryRun) {
            $this->newLine();
            $this->info('Dry run — nothing moved.');
            return self::SUCCESS;
        }

        $moved = 0;
        foreach ($files as $file) {
            // The database stores the same relative path on either disk, so
            // moving the bytes is the whole migration — no rows to update.
            if (! $local->exists($file)) {
                $local->put($file, $public->get($file));
            }

            $public->delete($file);
            $moved++;
        }

        $this->newLine();
        $this->info("Moved {$moved} file(s) to private storage.");
        $this->newLine();
        $this->warn('These files were publicly reachable until now.');
        $this->warn('Tell the people they belong to — it is their document and their call.');

        return self::SUCCESS;
    }
}
