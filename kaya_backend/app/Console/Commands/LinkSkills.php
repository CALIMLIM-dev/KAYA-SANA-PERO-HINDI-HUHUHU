<?php

namespace App\Console\Commands;

use App\Models\Skill;
use App\Models\SkillLink;
use App\Models\WorkerSkill;
use App\Services\SkillLinker;
use App\Services\SkillMatcher;
use Illuminate\Console\Command;

/*
    Links every typed word that is not linked yet. Nightly, for the ones the
    save could not do (Gemini down, the day's limit reached), and once by hand
    after deploying, for everything typed before linking existed.

    --seed also links a list of common Tagalog and Taglish trade words, so the
    words most people will type are known before anybody types them.
*/
class LinkSkills extends Command
{
    protected $signature = 'kaya:link-skills {--seed : Also link common Tagalog trade words} {--limit=200 : Most words to ask about in one run} {--pause=5 : Seconds between requests, to stay under the per-minute limit}';

    protected $description = 'Link typed skills to the catalogue with Gemini';

    private const SEED = [
        'tubero', 'tubera', 'plomero', 'pag-aayos ng tubo', 'pag-aayos ng gripo', 'barado ang lababo', 'ayos ng tagas',
        'elektrisyan', 'pag-aayos ng kuryente', 'kable at saksakan', 'pagkakabit ng ilaw',
        'pintor', 'pagpipintura', 'pintura ng bahay', 'repaint ng pader',
        'karpintero', 'anluwage', 'gawa ng aparador', 'ayos ng pinto', 'pagkukumpuni ng muwebles',
        'kantero', 'mason', 'pagbubuhos ng semento', 'pag-aayos ng pader',
        'hinang', 'manghihinang', 'welder',
        'bubong', 'pag-aayos ng bubong', 'tagas ng bubong',
        'hardinero', 'paghahalaman', 'pagputol ng damo',
        'tagalinis', 'paglilinis ng bahay', 'kasambahay', 'labandera', 'labahan', 'plantsa',
        'mekaniko', 'ayos ng sasakyan', 'ayos ng motor',
        'aircon', 'linis ng aircon', 'ayos ng ref',
        'kargador', 'hakot', 'lipat bahay',
        'drayber', 'tsuper', 'rider', 'padala',
        'yaya', 'tagapag-alaga ng bata', 'tagapag-alaga ng matanda',
        'kusinero', 'kusinera', 'tagaluto',
        'mananahi', 'sastre', 'modista', 'barbero', 'manikurista',
    ];

    public function handle(SkillLinker $linker): int
    {
        if (! $linker->enabled()) {
            $this->error('Linking is off: set EMBEDDING_API_KEY, and SKILL_LINKING_ENABLED is not false.');
            return self::FAILURE;
        }

        $budget = max(1, (int) $this->option('limit'));
        [$linked, $failed] = [0, 0];

        // Spaced out: the free tier allows only a few requests a minute.
        $pause = max(0, (int) $this->option('pause'));
        $tally = function (bool $ok) use (&$linked, &$failed, &$budget, $pause) {
            $ok ? $linked++ : $failed++;
            $budget--;
            if ($pause > 0) sleep($pause);
        };

        // Workers' own words, one row per distinct word.
        $seen = [];
        foreach (WorkerSkill::whereNull('skill_id')->orderBy('id')->cursor() as $row) {
            if ($budget <= 0) break;
            $term = SkillMatcher::normalise((string) $row->skill_name);
            if ($term === '' || isset($seen[$term]) || SkillLink::known($term)) continue;
            $seen[$term] = true;
            $tally($linker->linkWorkerSkill($row));
        }

        // Skills workers and employers added to the catalogue themselves.
        foreach (Skill::where('source', 'user')->orderBy('id')->cursor() as $skill) {
            if ($budget <= 0) break;
            if (SkillLink::known(SkillMatcher::normalise((string) $skill->name))) continue;
            $tally($linker->linkSkill($skill));
        }

        if ($this->option('seed')) {
            foreach (self::SEED as $word) {
                if ($budget <= 0) break;
                if (SkillLink::known(SkillMatcher::normalise($word))) continue;
                $tally($linker->linkWord($word));
            }
        }

        $this->info("Linked {$linked}, failed {$failed}" . ($budget <= 0 ? ' (stopped at the limit; run again)' : '') . '.');

        return self::SUCCESS;
    }
}
