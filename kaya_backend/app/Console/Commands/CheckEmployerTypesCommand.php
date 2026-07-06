<?php

namespace App\Console\Commands;

use App\Models\EmployerProfile;
use Illuminate\Console\Command;

class CheckEmployerTypesCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'employer:check-types';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Check for employer profiles with NULL employer_type before making column NOT NULL';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('Checking employer profiles for NULL employer_type...');

        $nullTypeProfiles = EmployerProfile::whereNull('employer_type')->get();
        $count = $nullTypeProfiles->count();

        if ($count === 0) {
            $this->info('✓ All employer profiles have employer_type set.');
            $this->info('Safe to proceed with making employer_type NOT NULL.');
            return self::SUCCESS;
        }

        $this->error("✗ Found {$count} employer profile(s) with NULL employer_type:");
        $this->newLine();

        $nullTypeProfiles->each(function ($profile) {
            $this->line("  ID: {$profile->id}, User: {$profile->user->name} ({$profile->user->email})");
        });

        $this->newLine();
        $this->warn('Action Required:');
        $this->line('  1. Contact these users to complete their employer profile setup');
        $this->line('  2. Or manually set employer_type for these profiles');
        $this->line('  3. Run this command again to verify all profiles are updated');
        $this->newLine();
        $this->error('Do NOT make employer_type NOT NULL until all profiles are updated.');

        return self::FAILURE;
    }
}
