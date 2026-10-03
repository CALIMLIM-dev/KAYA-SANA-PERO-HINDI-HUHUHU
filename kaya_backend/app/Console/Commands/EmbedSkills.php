<?php

namespace App\Console\Commands;

use App\Models\Skill;
use App\Models\SkillVector;
use App\Models\WorkerSkill;
use App\Services\Embeddings;
use App\Services\SkillMatcher;
use Illuminate\Console\Command;

/*
    Gives every skill name a vector, so two people describing the same trade
    differently can be matched.

    Walks the **distinct names**, not the rows that hold them. Thirty workers
    who all typed "Aircon Cleaning" are one term, one API call and one row -
    so the work here is the size of the vocabulary people actually typed,
    which is hundreds, and not the number of profiles, which is not.

    Safe to run as often as you like: a term that already has a vector for the
    current model is skipped, so a second run costs nothing and a run after
    somebody types a new skill costs exactly one call.
*/
class EmbedSkills extends Command
{
    protected $signature = 'kaya:embed-skills
        {--dry-run : List what would be fetched and change nothing}
        {--limit=0 : Stop after this many new terms, 0 for no limit}
        {--force : Refetch terms that already have a vector}';

    protected $description = 'Compute embeddings for skill names that do not have one yet';

    public function handle(Embeddings $embeddings): int
    {
        if (! $embeddings->enabled()) {
            $this->error('Embeddings are off: set EMBEDDING_API_KEY, or EMBEDDINGS_ENABLED=true.');
            $this->line('Matching keeps working without them - see SkillMatcher.');

            return self::FAILURE;
        }

        $model = $embeddings->model();
        $this->line("Model: {$model}");

        $terms = $this->distinctTerms();
        $this->line('Distinct skill names: '.count($terms));

        if (! $this->option('force')) {
            $have = SkillVector::where('model', $model)->pluck('term')->all();
            $terms = array_values(array_diff($terms, $have));
            $this->line('Already embedded: '.count($have));
        }

        $limit = (int) $this->option('limit');
        if ($limit > 0 && count($terms) > $limit) {
            $terms = array_slice($terms, 0, $limit);
        }

        if ($terms === []) {
            $this->info('Nothing to do.');

            return self::SUCCESS;
        }

        $this->line('To fetch: '.count($terms));

        if ($this->option('dry-run')) {
            foreach ($terms as $term) {
                $this->line('  would fetch: '.$term);
            }
            $this->info('Dry run. Nothing was fetched or written.');

            return self::SUCCESS;
        }

        $done = 0;
        $failed = 0;

        foreach ($terms as $term) {
            $vector = $embeddings->fetchAndStore($term);

            if ($vector === null) {
                $failed++;
                $this->warn('  failed: '.$term);

                /*
                    Stop after a run of failures rather than hammering a
                    provider that is down or a key that is wrong. Ten in a row
                    is not bad luck.
                */
                if ($failed >= 10 && $done === 0) {
                    $this->error('Ten failures and no successes - stopping. Check the key and the model name.');

                    return self::FAILURE;
                }

                continue;
            }

            $done++;

            if ($done % 25 === 0) {
                $this->line("  {$done} done");
            }

            // Gentle on a free tier. The whole job is a few hundred calls, so
            // a quarter second between them costs a minute and risks nothing.
            usleep(250_000);
        }

        $this->info("Embedded {$done} term(s)."
            . ($failed > 0 ? " {$failed} failed - run again to retry them." : ''));

        return self::SUCCESS;
    }

    /**
     * Every distinct normalised skill name on the platform.
     *
     * Both sides: the catalogue, which is what a job asks for, and what
     * workers actually typed, which is where the custom names live. A match
     * needs vectors for both or it has nothing to compare.
     *
     * @return list<string>
     */
    private function distinctTerms(): array
    {
        $terms = [];

        foreach (Skill::pluck('name') as $name) {
            $term = SkillMatcher::normalise((string) $name);
            if ($term !== '') {
                $terms[$term] = true;
            }
        }

        foreach (WorkerSkill::distinct()->pluck('skill_name') as $name) {
            $term = SkillMatcher::normalise((string) $name);
            if ($term !== '') {
                $terms[$term] = true;
            }
        }

        return array_keys($terms);
    }
}
