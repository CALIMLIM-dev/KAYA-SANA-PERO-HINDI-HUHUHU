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
