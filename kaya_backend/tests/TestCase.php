<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Cache;

abstract class TestCase extends BaseTestCase
{
    /*
        Databases this suite is allowed to touch.

        RefreshDatabase drops every table in whatever database it is pointed at.
        Tests now run on MySQL so their schema matches production — the previous
        SQLite default let `applications.status` drift, and a whole feature had
        no test that could ever have passed — but running them on MySQL means a
        single wrong value in phpunit.xml or a stale .env destroys the
        development database instead of a throwaway copy.

        So the name is checked before any test runs. A misconfiguration fails
        loudly on the first test rather than quietly deleting the accounts,
        jobs, applications and uploaded documents the team is testing against.
        There is no undo for that, and no backup here to restore from.
    */
    private const ALLOWED_TEST_DATABASES = ['kaya_db_test', ':memory:'];

    protected function setUp(): void
    {
        parent::setUp();

        $this->guardAgainstWipingTheRealDatabase();

        /*
            Rate limit state does not belong to one test.

            The API now carries a global throttle. The limiter keys on the
            token or the client IP, and in a test run both are effectively
            constant — so the requests from every earlier test accumulate, and
            a test somewhere in the middle of the suite starts getting 429s for
            requests it never made. That failure moves depending on the order
            tests happen to run in, which is the worst kind to debug.

            Cleared per test rather than switched off, so throttling is still
            the real middleware and a test that deliberately exercises a limit
            (login, password reset) still sees it.
        */
        /*
            The limiter keeps its counters in the cache, and an inline
            `throttle:10,10` on a route has no name to clear by — its key is
            derived from the route and the caller. Clearing a list of names
            therefore missed most of them, and a test in the middle of the
            suite would start seeing 429s for requests it never made.

            Flushing the store clears every counter regardless of how its key
            was built. Safe in tests, where nothing else depends on cached
            state surviving between them.
        */
        Cache::flush();
    }

    /*
        A worker profile complete enough to transact with.

        Applying and accepting an invitation require a trade and at least one
        skill: a profile row exists from the moment setup starts, so without
        that check an abandoned attempt could put a card in front of an
        employer that says nothing about the person behind it.

        Most tests here only ever needed "this user is a worker" and wrote a
        bare row to say so, which is a profile no employer could read. This is
        that same intent, expressed as a profile that could really exist.
    */
    /*
        An account that has bought barya once.

        Boosting, a post past the free week and a second board post are for
        topped-up accounts now. Tests about how those features behave start
        from an account that may use them; FreeVsTopUpTest covers the refusal.
        Delta zero: only the fact of the purchase counts, never the amount,
        and a balance the test set up stays the balance it set up.
    */
    protected function topUp(\App\Models\User $user): \App\Models\User
    {
        \App\Models\CreditTransaction::create([
            'user_id'       => $user->id,
            'delta'         => 0,
            'balance_after' => 0,
            'reason'        => \App\Models\CreditTransaction::REASON_TOPUP,
        ]);

        return $user;
    }

    protected function seedWorkerProfile(
        \App\Models\User $user,
        array $attributes = [],
    ): \App\Models\WorkerProfile {
        $category = \App\Models\Category::firstOrCreate(
            ['name' => 'General Labour'],
            ['description' => 'Seeded by the test suite.'],
        );

        $profile = \App\Models\WorkerProfile::create(array_merge([
            'user_id'     => $user->id,
            'category_id' => $category->id,
            /*
                A complete profile by the panel's rule - see
                WorkerProfile::REQUIREMENTS. A caller that cares about the
                place, the photo or the rate passes its own; one that does not
                still gets a profile that could apply for work.
            */
            'location'    => 'Urdaneta City',
            'latitude'    => 15.9761,
            'longitude'   => 120.5711,
            'profile_photo_path' => 'worker_photos/seeded.jpg',
            'rate_by_agreement'  => true,
        ], $attributes));

        \App\Models\WorkerSkill::firstOrCreate([
            'user_id'    => $user->id,
            'skill_name' => 'General labour',
        ], [
            'category_id' => $category->id,
            'years_of_experience' => 2,
        ]);

        return $profile;
    }

    /**
     * Refuses to run against anything but a designated test database.
     *
     * Checks the connection's actual resolved name rather than the env value,
     * so a DB_URL or a cached config that overrides DB_DATABASE cannot slip
     * past it.
     */
    private function guardAgainstWipingTheRealDatabase(): void
    {
        $connection = config('database.default');
        $database = (string) config("database.connections.{$connection}.database");

        if (in_array($database, self::ALLOWED_TEST_DATABASES, true)) {
            return;
        }

        $this->fail(
            "Refusing to run tests against the '{$database}' database.\n\n".
            "The suite uses RefreshDatabase, which drops every table in the ".
            "database it is connected to. '{$database}' is not in the allowed ".
            "list (".implode(', ', self::ALLOWED_TEST_DATABASES)."), so this ".
            "is almost certainly pointed at real data.\n\n".
            "Fix phpunit.xml, or run: php artisan config:clear"
        );
    }
}
