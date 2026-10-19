<?php

namespace Tests\Feature;

use App\Models\ServerError;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A 500 is written down where an administrator can read it. The server's
    own log goes to stderr and nobody can open it.
*/
class ServerErrorsTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_failing_request_is_recorded_once_and_counted(): void
    {
        Route::get('/api/v1/__boom', fn () => throw new \RuntimeException('Broke on purpose'))->middleware('api');

        $this->getJson('/api/v1/__boom')->assertStatus(500);
        $this->getJson('/api/v1/__boom')->assertStatus(500);

        $row = ServerError::sole();
        $this->assertSame('Broke on purpose', $row->message);
        $this->assertSame(2, $row->count);
        $this->assertStringContainsString('ServerErrorsTest.php', $row->file);
        $this->assertSame('GET', $row->method);
    }

    #[Test]
    public function a_refused_request_is_not_an_error(): void
    {
        $this->postJson('/api/v1/login', [])->assertStatus(422);

        $this->assertSame(0, ServerError::count());
    }

    #[Test]
    public function the_page_lists_them(): void
    {
        ServerError::capture(new \LogicException('Listed here'));
        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)->get('/admin/errors')
            ->assertOk()
            ->assertSee('Listed here')
            ->assertSee('Server Errors');
    }
}
