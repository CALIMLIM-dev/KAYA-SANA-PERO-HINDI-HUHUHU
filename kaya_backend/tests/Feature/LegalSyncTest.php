<?php

namespace Tests\Feature;

use App\Console\Commands\LegalSync;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The website's Terms and Privacy Policy say exactly what the app says.
    If this fails, run: php artisan kaya:legal-sync
*/
class LegalSyncTest extends TestCase
{
    #[Test]
    public function the_website_copy_matches_the_app(): void
    {
        $expected = LegalSync::build();
        $actual = json_decode(file_get_contents(resource_path('legal_content.json')), true);

        $this->assertNotEmpty($expected['terms']);
        $this->assertNotEmpty($expected['privacy']);
        $this->assertSame($expected, $actual, 'The website legal text is out of date. Run php artisan kaya:legal-sync.');
    }

    #[Test]
    public function the_pages_show_the_new_sections(): void
    {
        $this->get('/terms')->assertOk()->assertSee('Your Account and Recovery')->assertSee('KAYA Support');
        $this->get('/privacy')->assertOk()->assertSee('textbee')->assertSee('Clipboard');
    }
}
