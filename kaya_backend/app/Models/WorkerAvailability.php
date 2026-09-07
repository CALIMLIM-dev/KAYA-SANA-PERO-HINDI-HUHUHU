<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/*
    One day, one period, for one worker.

    The whole pattern is a handful of these rows. Written as a set - the
    endpoint replaces every row for the worker rather than editing them
    individually - because a weekly pattern is answered as a whole ("weekends
    and weekday mornings"), never one checkbox at a time, and diffing it row by
    row would leave orphans whenever a save failed halfway.
*/
class WorkerAvailability extends Model
{
    protected $table = 'worker_availability';

    protected $fillable = ['user_id', 'day_of_week', 'period'];

    protected $casts = ['day_of_week' => 'integer'];

    public const PERIODS = ['morning', 'afternoon', 'evening', 'whole_day'];

    /// 0 = Sunday, matching Carbon's dayOfWeek.
    public const DAYS = [
        0 => 'Sun',
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function periodLabel(): string
    {
        return match ($this->period) {
            'morning' => 'Morning',
            'afternoon' => 'Afternoon',
            'evening' => 'Evening',
            default => 'Whole day',
        };
    }

    /*
        The pattern in one line, for a profile or a card.

        Built here rather than in the app so the public profile, the directory
        card and the admin panel cannot each phrase it differently. Consecutive
        days are collapsed - "Mon-Fri" reads, "Mon, Tue, Wed, Thu, Fri" is a
        list somebody has to parse.
    */
    public static function summarise(iterable $rows): ?string
    {
        $byDay = [];

        foreach ($rows as $row) {
            $byDay[$row->day_of_week][] = $row->period;
        }

        if ($byDay === []) {
            return null;
        }

        ksort($byDay);

        // Group days that offer exactly the same periods, so a pattern that
        // repeats is said once.
        $groups = [];

        foreach ($byDay as $day => $periods) {
            sort($periods);
            $key = implode(',', $periods);

            if ($groups !== [] && array_key_last($groups) !== null) {
                $last = &$groups[array_key_last($groups)];

                if ($last['key'] === $key && $last['days'][count($last['days']) - 1] === $day - 1) {
                    $last['days'][] = $day;
                    unset($last);
                    continue;
                }

                unset($last);
            }

            $groups[] = ['key' => $key, 'days' => [$day], 'periods' => $periods];
        }

        $parts = [];

        foreach ($groups as $group) {
            $days = $group['days'];

            $label = count($days) > 2
                ? self::DAYS[$days[0]] . '-' . self::DAYS[$days[count($days) - 1]]
                : implode(', ', array_map(fn ($d) => self::DAYS[$d], $days));

            $when = in_array('whole_day', $group['periods'], true)
                ? null
                : implode('/', array_map(
                    fn ($p) => ucfirst($p),
                    $group['periods']
                ));

            $parts[] = $when === null ? $label : "{$label} {$when}";
        }

        return implode(', ', $parts);
    }
}
