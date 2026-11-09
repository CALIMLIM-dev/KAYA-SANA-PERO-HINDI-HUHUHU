<?php

namespace App\Console\Commands;

use App\Models\SkillVector;
use App\Services\Embeddings;
use Illuminate\Console\Command;

/*
    How well each embedding model tells KAYA's words apart, on KAYA's own
    pairs: names that mean the same work (Tagalog and English, a trade and
    its worker) and names that must not match (two different trades).

    Each model's "close enough" has to sit above every pair that must not
    match and below every pair that should. This prints both models' scores
    and the bar that separates them, which is what goes in
    EMBEDDING_BACKUP_THRESHOLD for the backup. Saves nothing.
*/
class EmbeddingTest extends Command
{
    protected $signature = 'kaya:embedding-test';

    protected $description = 'Score both embedding models on KAYA word pairs and suggest each one\'s threshold';

    /** Should match: the same work in other words. */
    private const SAME = [
        ['tubero', 'Plumbing'],
        ['karpintero', 'Carpentry'],
        ['pintor', 'Painting'],
        ['elektrisyan', 'Electrical Wiring'],
        ['ayos ng gripo', 'Faucet Repair'],
        ['paglilinis ng bahay', 'House Cleaning'],
        ['pagmamason', 'Masonry'],
        ['aircon cleaning', 'Aircon Repair'],
        ['hinang', 'Welding'],
        ['labandera', 'Laundry'],
        ['screen replacement', 'LCD Replacement'],
        ['drayber', 'Driving'],
    ];

    /** Must not match: different trades. */
    private const DIFFERENT = [
        ['Plumbing', 'Carpentry'],
        ['Painting', 'Electrical Wiring'],
        ['Welding', 'Cooking'],
        ['House Cleaning', 'Masonry'],
        ['Aircon Repair', 'Laundry'],
        ['tubero', 'karpintero'],
        ['Driving', 'Plumbing'],
        ['pintor', 'labandera'],
    ];

    public function handle(Embeddings $embeddings): int
    {
        $models = $embeddings->activeModels();
        if ($models === []) {
            $this->error('No embedding model is set up: EMBEDDING_API_KEY for Gemini, OMNIROUTE_URL and OMNIROUTE_KEY for the backup.');

            return self::FAILURE;
        }

        foreach ($models as $model) {
            $this->newLine();
            $this->info("Model: {$model}");

            $vectors = [];
            $vector = function (string $term) use ($embeddings, $model, &$vectors) {
                return $vectors[$term] ??= $embeddings->fetchAndStore($term, $model, store: false);
            };

            $score = fn (array $pair) => ($a = $vector($pair[0])) && ($b = $vector($pair[1])) ? SkillVector::cosine($a, $b) : null;

            $rows = [];
            $same = $different = [];
            foreach (self::SAME as $pair) {
                $s = $score($pair);
                $rows[] = ['should match', "{$pair[0]} = {$pair[1]}", $s === null ? 'no answer' : number_format($s, 3)];
                if ($s !== null) $same[] = $s;
            }
            foreach (self::DIFFERENT as $pair) {
                $s = $score($pair);
                $rows[] = ['must not', "{$pair[0]} / {$pair[1]}", $s === null ? 'no answer' : number_format($s, 3)];
                if ($s !== null) $different[] = $s;
            }
            $this->table(['Kind', 'Pair', 'Score'], $rows);

            if ($same === [] || $different === []) {
                $this->warn('Not enough answers to judge this model.');
                continue;
            }

            $lowestSame = min($same);
            $highestDifferent = max($different);
            $this->line(sprintf('Lowest "should match": %.3f   Highest "must not": %.3f', $lowestSame, $highestDifferent));

            if ($lowestSame > $highestDifferent) {
                $this->info(sprintf('Separates cleanly. Suggested threshold: %.2f', ($lowestSame + $highestDifferent) / 2));
            } else {
                $missed = count(array_filter($same, fn ($s) => $s <= $highestDifferent));
                $this->warn(sprintf(
                    'Overlaps: %d "should match" pairs score at or below a "must not" pair. Suggested threshold: %.2f (keeps every "must not" out).',
                    $missed,
                    $highestDifferent + 0.01,
                ));
            }
        }

        return self::SUCCESS;
    }
}
