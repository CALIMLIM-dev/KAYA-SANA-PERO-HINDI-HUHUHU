<?php

namespace App\Support;

use App\Models\SystemSetting;
use Illuminate\Database\QueryException;

/*
    The prices an administrator can change from the panel.

    They live in config/kaya.php with .env defaults, and until this the only
    way to change one was to edit the server's .env and clear the config
    cache. Now a saved value in system_settings overrides the config at boot,
    so the panel, the API and the sweep all read the same number.

    Only these keys, and only whole numbers inside a stated range. The
    config file stays the place that explains why each default is what it
    is; this is the place that lets the number move without a deploy.
*/
class Pricing
{
    public const GROUP = 'pricing';

    /** config path => [label, hint, min, max, unit] */
    public const FIELDS = [
        'kaya.credits.apply' => [
            'label' => 'Apply for a job',
            'hint'  => 'Paid by the worker for each application.',
            'min' => 0, 'max' => 100, 'unit' => 'Barya',
        ],
        'kaya.credits.invite' => [
            'label' => 'Invite a worker',
            'hint'  => 'Paid by the employer for each invitation.',
            'min' => 0, 'max' => 100, 'unit' => 'Barya',
        ],
        'kaya.credits.rehire_invite' => [
            'label' => 'Invite a worker again',
            'hint'  => 'An invitation to someone the employer already hired.',
            'min' => 0, 'max' => 100, 'unit' => 'Barya',
        ],
        'kaya.credits.unlock' => [
            'label' => 'Unlock contact details',
            'hint'  => 'Once per worker, kept forever.',
            'min' => 0, 'max' => 500, 'unit' => 'Barya',
        ],
        'kaya.credits.boost' => [
            'label' => 'Boost a post',
            'hint'  => 'Top of the feed for the boost days below.',
            'min' => 0, 'max' => 500, 'unit' => 'Barya',
        ],
        'kaya.credits.boost_days' => [
            'label' => 'Boost length',
            'hint'  => 'How many days a boost lasts.',
            'min' => 1, 'max' => 30, 'unit' => 'days',
        ],
        'kaya.jobs.free_days' => [
            'label' => 'Free post days',
            'hint'  => 'A post up to this long costs nothing.',
            'min' => 0, 'max' => 90, 'unit' => 'days',
        ],
        'kaya.credits.post_days_per_barya' => [
            'label' => 'Post days per Barya',
            'hint'  => 'Past the free days, one Barya buys this many more.',
            'min' => 1, 'max' => 30, 'unit' => 'days',
        ],
        'kaya.credits.signup_grant' => [
            'label' => 'Welcome grant',
            'hint'  => 'Given once when an account first gets a wallet.',
            'min' => 0, 'max' => 500, 'unit' => 'Barya',
        ],
        'kaya.credits.monthly_grant' => [
            'label' => 'Monthly grant',
            'hint'  => 'Given to every account each month.',
            'min' => 0, 'max' => 500, 'unit' => 'Barya',
        ],
    ];

    /** Lays the saved values over the config. Called once at boot. */
    public static function apply(): void
    {
        try {
            $saved = SystemSetting::where('group', self::GROUP)->pluck('value', 'key');
        } catch (QueryException) {
            // No table yet: a fresh install running its first migrate.
            return;
        }

        foreach ($saved as $key => $value) {
            if (isset(self::FIELDS[$key]) && $value !== null && $value !== '') {
                config([$key => (int) $value]);
            }
        }
    }

    /** What the panel shows: the live value for each field. */
    public static function current(): array
    {
        $out = [];
        foreach (self::FIELDS as $key => $field) {
            $out[$key] = $field + ['value' => (int) config($key)];
        }

        return $out;
    }

    /** Saves one field and makes it live for the rest of this request. */
    public static function set(string $key, int $value): void
    {
        SystemSetting::updateOrCreate(
            ['key' => $key],
            ['value' => (string) $value, 'label' => self::FIELDS[$key]['label'], 'group' => self::GROUP],
        );

        config([$key => $value]);
    }

    /** Field names as the form posts them: dots are not allowed in input names. */
    public static function formName(string $key): string
    {
        return str_replace('.', '__', $key);
    }

    public static function fromFormName(string $name): string
    {
        return str_replace('__', '.', $name);
    }
}
