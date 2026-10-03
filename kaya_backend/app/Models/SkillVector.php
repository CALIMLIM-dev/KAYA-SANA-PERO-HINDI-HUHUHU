<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A stored embedding for one normalised skill term.
 *
 * See the migration for why this is keyed on the term and the model rather
 * than on a skill row.
 */
class SkillVector extends Model
{
    protected $fillable = ['term', 'model', 'dimensions', 'values'];

    protected $casts = [
        'values'     => 'array',
        'dimensions' => 'integer',
    ];

    /**
     * Cosine similarity between two vectors of the same length.
     *
     * Returns null rather than zero when the vectors cannot be compared -
     * different lengths means different models, and a number there would be
     * meaningless rather than merely wrong.
     *
     * @param  list<float>  $a
     * @param  list<float>  $b
     */
    public static function cosine(array $a, array $b): ?float
    {
        $n = count($a);

        if ($n === 0 || $n !== count($b)) {
            return null;
        }

        $dot = 0.0;
        $normA = 0.0;
        $normB = 0.0;

        /*
            One pass, indexed rather than iterated.

            This runs a few hundred times per feed over 768 dimensions, so it
            is the one place in this feature where the shape of the loop
            matters. array_sum with array_map would allocate three arrays per
            comparison.
        */
        for ($i = 0; $i < $n; $i++) {
            $x = (float) $a[$i];
            $y = (float) $b[$i];

            $dot += $x * $y;
            $normA += $x * $x;
            $normB += $y * $y;
        }

        if ($normA <= 0.0 || $normB <= 0.0) {
            return null;
        }

        return $dot / (sqrt($normA) * sqrt($normB));
    }
}
