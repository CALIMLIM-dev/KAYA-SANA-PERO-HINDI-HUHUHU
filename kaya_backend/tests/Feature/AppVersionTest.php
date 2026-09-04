<?php

namespace Tests\Feature;

use Tests\TestCase;

/*
    The version check the app makes on startup.

    KAYA ships as an APK handed out directly, so nothing updates anybody and a
    tester can spend a day on a build from three fixes ago. The endpoint has to
    be reachable before login - that is exactly when somebody on an ancient
    build is trying to get in - and it has to be right about what "too old"
    means, because the answer locks people out.
*/
class AppVersionTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config([
            'kaya.app.minimum_version' => '1.2.0',
            'kaya.app.latest_version'  => '1.3.0',
            'kaya.app.download_url'    => 'https://example.test/kaya.apk',
        ]);
    }

    public function test_it_answers_without_a_login(): void
    {
        $this->getJson('/api/v1/version/1.3.0')
            ->assertOk()
            ->assertJsonPath('data.update_required', false);
    }

    public function test_a_build_below_the_minimum_must_update(): void
    {
        $this->getJson('/api/v1/version/1.1.9')
            ->assertOk()
            ->assertJsonPath('data.update_required', true)
            ->assertJsonPath('data.download_url', 'https://example.test/kaya.apk');
    }

    /*
        Supported but not newest is a suggestion, never a wall.

        Most releases are not breaking, and locking somebody out of a working
        app to fetch a nicety is worse than the nicety.
    */
    public function test_a_build_between_minimum_and_latest_is_only_offered_an_update(): void
    {
        $this->getJson('/api/v1/version/1.2.0')
            ->assertOk()
            ->assertJsonPath('data.update_required', false)
            ->assertJsonPath('data.update_available', true);
    }

    public function test_the_newest_build_is_told_nothing(): void
    {
        $this->getJson('/api/v1/version/1.3.0')
            ->assertOk()
            ->assertJsonPath('data.update_required', false)
            ->assertJsonPath('data.update_available', false);
    }

    /*
        Flutter writes "1.2.1+4" and the build number is not part of the
        version. Left in, version_compare cannot parse it and every client
        would be told it was too old - a check that locks out the newest build
        is worse than no check.
    */
    public function test_a_flutter_build_suffix_is_ignored(): void
    {
        $this->getJson('/api/v1/version/1.3.0+7')
            ->assertOk()
            ->assertJsonPath('data.update_required', false);
    }

    /*
        A build that cannot say what it is predates this endpoint, so it is
        older than any minimum by definition.
    */
    public function test_a_missing_version_is_treated_as_too_old(): void
    {
        $this->getJson('/api/v1/app-version')
            ->assertOk()
            ->assertJsonPath('data.update_required', true);
    }

    public function test_the_query_string_form_works_too(): void
    {
        $this->getJson('/api/v1/app-version?version=1.3.0')
            ->assertOk()
            ->assertJsonPath('data.update_required', false);
    }
}
