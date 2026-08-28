<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * The public terms and privacy pages.
 *
 * They exist for the Google sign-in consent screen, which links to them by
 * URL - if they 404, that link is dead. Public, because consent is shown
 * before anyone signs in.
 */
class LegalPagesTest extends TestCase
{
    #[\PHPUnit\Framework\Attributes\Test]
    public function terms_page_is_public_and_has_content(): void
    {
        $this->get('/terms')
            ->assertOk()
            ->assertSee('Terms and Conditions')
            ->assertSee('Who Can Use KAYA');
    }

    #[\PHPUnit\Framework\Attributes\Test]
    public function privacy_page_is_public_and_has_content(): void
    {
        $this->get('/privacy')
            ->assertOk()
            ->assertSee('Privacy Policy')
            ->assertSee('Information We Collect');
    }
}
