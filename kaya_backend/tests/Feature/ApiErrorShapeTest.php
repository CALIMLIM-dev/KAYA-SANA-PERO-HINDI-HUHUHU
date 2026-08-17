<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Every /api response is JSON, including the failures.

    Laravel picks the format from the Accept header. The Flutter client sends
    `Accept: application/json`, so this looked correct — but only because the
    client happened to ask nicely. Without the header the same error came back as
    an HTML page, which Dio then failed to parse, turning a clean 404 into an
    unexplained "Something went wrong" with the status code lost on the way.

    These tests drop the header deliberately. That is the case that was broken.
*/
class ApiErrorShapeTest extends TestCase
{
    use RefreshDatabase;

    public function test_unknown_api_route_returns_json_without_an_accept_header(): void
    {
        $response = $this->get('/api/v1/this-route-does-not-exist');

        $response->assertStatus(404);
        $response->assertHeader('content-type', 'application/json');
        $this->assertStringNotContainsString('<!DOCTYPE', $response->getContent());

        // Parses as JSON rather than merely looking like it.
        $this->assertIsArray($response->json());
    }

    public function test_unauthenticated_api_request_returns_json_not_a_login_redirect(): void
    {
        /*
            The web guard's answer to "not logged in" is a 302 to the login page.
            For an API client that redirect is worse than useless: Dio follows it
            and reports the resulting HTML, so an expired token reads as a parse
            failure rather than as a 401, and the app never triggers its re-auth.
        */
        $response = $this->get('/api/v1/me');

        $response->assertStatus(401);
        $response->assertHeader('content-type', 'application/json');
        $this->assertArrayHasKey('message', $response->json());
    }

    public function test_validation_failure_keeps_the_errors_bag_the_client_parses(): void
    {
        /*
            ApiClient._handleError reads errors.<field>[0] to surface the first
            message. A shape change here breaks every form in the app at once.

            An empty body rather than a malformed one: login's `email` field is
            only `required|string`, because it accepts a phone number there too.
        */
        $response = $this->postJson('/api/v1/login', []);

        $response->assertStatus(422);
        $response->assertJsonStructure(['message', 'errors' => ['email', 'password']]);
        $this->assertIsArray($response->json('errors.email'));
        $this->assertIsString($response->json('errors.email.0'));
    }

    public function test_web_routes_are_unaffected_and_still_render_html(): void
    {
        // The path rule must not leak onto the admin panel, which is server-
        // rendered Blade and needs its HTML error pages.
        $response = $this->get('/admin/login');

        $response->assertStatus(200);
        $this->assertStringContainsString('text/html', $response->headers->get('content-type'));
    }
}
