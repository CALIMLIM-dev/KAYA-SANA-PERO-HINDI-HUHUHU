<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    A Philippine name is four fields, and `name` is derived from them.

    The split keeps `name` rather than dropping it, because every reader in the
    app and the whole admin panel still use it. That is only safe while it
    cannot drift from the parts, so these tests are mostly about the one rule
    that makes the arrangement work: the parts are the source of truth, and
    `name` is recomputed from them on every save that touches them.
*/
class UserNamePartsTest extends TestCase
{
    use RefreshDatabase;

    public function test_display_name_is_composed_from_the_parts(): void
    {
        $user = User::factory()->create([
            'first_name'  => 'Juan',
            'middle_name' => 'Perez',
            'last_name'   => 'Dela Cruz',
            'suffix'      => 'Jr.',
        ]);

        $this->assertSame(
            'Juan P. Dela Cruz Jr.',
            $user->fresh()->name,
            'The middle name is the mother\'s maiden surname and shows as an '
            . 'initial; the full value stays in its own column.'
        );
    }

    public function test_optional_parts_leave_no_gaps(): void
    {
        $user = User::factory()->create([
            'first_name'  => 'Maria',
            'middle_name' => null,
            'last_name'   => 'Santos',
            'suffix'      => null,
        ]);

        $this->assertSame(
            'Maria Santos',
            $user->fresh()->name,
            'Missing optional parts must not leave double spaces or a trailing '
            . 'gap — this string is shown next to avatars.'
        );
    }

    public function test_editing_one_part_rebuilds_the_display_name(): void
    {
        $user = User::factory()->create([
            'first_name' => 'Juan',
            'last_name'  => 'Santos',
        ]);

        $user->update(['last_name' => 'Dela Cruz']);

        $this->assertSame(
            'Juan Dela Cruz',
            $user->fresh()->name,
            'A stale display name beside an edited surname is worse than never '
            . 'having split the column — the two would disagree with nothing '
            . 'to say which is current.'
        );
    }

    /*
        An account with no parts keeps the name it has.

        Everything created before the migration, and any Google sign-in that
        only ever supplied a display name, is in this state. Saving something
        unrelated must not blank it.
    */
    public function test_an_account_without_parts_keeps_its_name(): void
    {
        $user = User::factory()->create([
            'name'       => 'Existing Person',
            'first_name' => null,
            'last_name'  => null,
        ]);

        $user->update(['city' => 'Urdaneta City']);

        $this->assertSame('Existing Person', $user->fresh()->name);
    }

    public function test_the_parts_are_returned_and_saved_through_me(): void
    {
        $user = User::factory()->create(['is_verified' => false]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', [
                'first_name'  => 'Jose',
                'middle_name' => 'Rizal',
                'last_name'   => 'Mercado',
            ])
            ->assertOk();

        $this->assertSame('Jose R. Mercado', $user->fresh()->name);
    }

    /*
        The verification lock has to cover the parts too.

        `name` is guarded because an administrator matched it to a government
        ID. Now that `name` is derived, writing the parts without the same
        check would walk straight around it — rename via first_name, keep the
        badge that vouched for the old name.
    */
    public function test_a_verified_account_cannot_rename_itself_through_the_parts(): void
    {
        $user = User::factory()->create([
            'first_name'  => 'Juan',
            'last_name'   => 'Dela Cruz',
            'is_verified' => true,
        ]);

        $before = $user->fresh()->name;

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['last_name' => 'Santos'])
            ->assertStatus(422);

        $this->assertSame($before, $user->fresh()->name);
    }

    public function test_a_verified_account_may_still_save_the_same_name(): void
    {
        $user = User::factory()->create([
            'first_name'  => 'Juan',
            'last_name'   => 'Dela Cruz',
            'is_verified' => true,
        ]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', [
                'first_name' => 'Juan',
                'last_name'  => 'Dela Cruz',
            ])
            ->assertOk();
    }
    /*
        The lock is only as good as what /me sends.

        Both setup flows decide whether to freeze the name fields from this
        payload. It carried the composed name and nothing else, so the parts
        read null and the lock never came on - a hybrid could set the second
        profile up under a different name. The screens are fixed; this keeps
        the payload they depend on from quietly losing a field again.
    */
    public function test_me_returns_the_name_parts_and_whether_the_name_is_locked(): void
    {
        $user = User::factory()->create([
            'first_name'  => 'Juan',
            'middle_name' => 'Reyes',
            'last_name'   => 'Dela Cruz',
            'suffix'      => 'Jr.',
            'is_verified' => false,
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.first_name', 'Juan')
            ->assertJsonPath('data.middle_name', 'Reyes')
            ->assertJsonPath('data.last_name', 'Dela Cruz')
            ->assertJsonPath('data.suffix', 'Jr.')
            // A name is already on the account, so setting up the other
            // profile cannot propose a different one.
            ->assertJsonPath('data.name_locked', true);
    }

    public function test_an_account_with_no_name_yet_is_not_locked(): void
    {
        $user = User::factory()->create([
            'name'        => '',
            'first_name'  => null,
            'last_name'   => null,
            'is_verified' => false,
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.name_locked', false);
    }
}
