<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

/**
 * Copies the Terms and Privacy Policy from the app into the website.
 *
 * The app's legal_documents.dart is where the wording lives; /terms and
 * /privacy read resources/legal_content.json. That file was copied by hand
 * once and then drifted - the website still said September after the app
 * had been updated in November. This rebuilds it, and LegalSyncTest fails
 * whenever the two disagree.
 *
 *     php artisan kaya:legal-sync
 */
class LegalSync extends Command
{
    protected $signature = 'kaya:legal-sync';

    protected $description = 'Rebuild the website Terms and Privacy Policy from the app';

    public static function source(): string
    {
        return base_path('../kaya_app/lib/features/legal/data/legal_documents.dart');
    }

    /** The website copy, as it should be, read from the app's file. */
    public static function build(): array
    {
        $dart = str_replace("\r\n", "\n", (string) file_get_contents(self::source()));

        preg_match("/static const String lastUpdated = '([^']*)';/", $dart, $updated);

        $out = ['updated' => $updated[1] ?? ''];
        foreach (['terms', 'privacy'] as $which) {
            $start = strpos($dart, "static const LegalDocument {$which} = LegalDocument(");
            $end = $start === false ? false : strpos($dart, "\n  );", $start);
            $block = $start === false || $end === false ? '' : substr($dart, $start, $end - $start);

            preg_match_all("/LegalSection\(\s*'((?:[^'\\\\]|\\\\.)*)',\s*'((?:[^'\\\\]|\\\\.)*)',?\s*\)/s", $block, $m, PREG_SET_ORDER);
            $out[$which] = array_map(fn ($s) => [
                'title' => self::unescape($s[1]),
                'body'  => self::unescape($s[2]),
            ], $m);
        }

        return $out;
    }

    private static function unescape(string $s): string
    {
        return strtr($s, ['\\n' => "\n", "\\'" => "'", '\\\\' => '\\', '\\$' => '$']);
    }

    public function handle(): int
    {
        $data = self::build();
        if ($data['terms'] === [] || $data['privacy'] === []) {
            $this->error('Could not read the sections from ' . self::source());

            return self::FAILURE;
        }

        file_put_contents(
            resource_path('legal_content.json'),
            json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n",
        );
        $this->info(sprintf('Website updated: %d terms sections, %d privacy sections, %s.',
            count($data['terms']), count($data['privacy']), $data['updated']));

        return self::SUCCESS;
    }
}
