<?php

namespace App\Console\Commands;

use App\Enums\AdminRole;
use App\Models\User;
use App\Services\AdminAccounts;
use Illuminate\Console\Command;

/*
    Makes an administrator from the server and prints its password.

    The same as the New Administrator form, for when nobody can sign in to
    the panel yet, or to make several at once. The password is printed here
    and nowhere else; it is not logged.

        php artisan kaya:make-admin ana@example.ph verifier --name="Ana Reyes"
*/
class MakeAdmin extends Command
{
    protected $signature = 'kaya:make-admin {email} {role} {--name= : Shown in the panel; defaults to the part of the email before the @}';

    protected $description = 'Create an administrator with a generated password, printed once';

    public function handle(AdminAccounts $accounts): int
    {
        $email = mb_strtolower(trim((string) $this->argument('email')));
        $role = AdminRole::tryFrom((string) $this->argument('role'));

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error("{$email} is not an email address.");
            return self::FAILURE;
        }

        if ($role === null) {
            $this->error('Role must be one of: ' . implode(', ', array_column(AdminRole::cases(), 'value')));
            return self::FAILURE;
        }

        if (User::where('email', $email)->exists()) {
            $this->error("{$email} already has an account.");
            return self::FAILURE;
        }

        $name = trim((string) $this->option('name')) ?: strstr($email, '@', true);

        [$user, $password] = $accounts->create($name, $email, $role);

        $this->line("Created {$user->name} as {$role->label()}.");
        $this->line("  Sign in at  " . route('admin.login'));
        $this->line("  Email       {$user->email}");
        $this->line("  Password    {$password}");
        $this->line('They are asked to choose their own password at first sign-in.');

        return self::SUCCESS;
    }
}
