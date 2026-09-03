<?php

namespace App\Console\Commands;

use App\Enums\EmployerType;
use App\Models\User;
use Illuminate\Console\Command;

/*
    Lists accounts that hold both a company employer profile and a worker
    profile, and changes nothing.

    Going forward those two cannot coexist. Accounts that already have both
    were made before the rule and are deliberately left alone: this is a live
    system in testing, and taking a profile away from somebody who is part way
    through demonstrating it is a worse outcome than a short list of
    grandfathered accounts.

    Read-only on purpose. If these ever do need resolving it should be a
    decision made per account with the person's knowledge, not a sweep — which
    is why this reports and stops rather than offering a --fix.
*/
class AuditCompanyHybrids extends Command
{
    protected $signature = 'kaya:audit-company-hybrids';

    protected $description = 'List accounts holding both a company employer profile and a worker profile';

    public function handle(): int
    {
        $accounts = User::query()
            ->whereHas('workerProfile')
            ->whereHas('employerProfile', fn ($q) => $q->where('employer_type', EmployerType::COMPANY->value))
            ->with('employerProfile:id,user_id,company_name')
            ->get(['id', 'name', 'email']);

        if ($accounts->isEmpty()) {
            $this->info('No accounts hold both a company profile and a worker profile.');
            return self::SUCCESS;
        }

        $this->warn("{$accounts->count()} account(s) predate the company/worker rule:");

        $this->table(
            ['id', 'name', 'email', 'company'],
            $accounts->map(fn (User $u) => [
                $u->id,
                $u->name,
                $u->email,
                $u->employerProfile?->company_name ?? '(unnamed)',
            ])->all()
        );

        $this->line('');
        $this->line('Left as they are. Nothing was changed.');

        return self::SUCCESS;
    }
}
