<?php

namespace App\Support;

use App\Models\SystemSetting;
use Illuminate\Database\QueryException;

/*
    The KAYA Assistant and Safety Check settings, editable in the admin.

    Each one is a config path with its default in config/kaya.php or
    config/moderation.php; a saved value is laid over the config once at
    boot, the way Pricing does, so the code keeps reading config() and the
    admin can change it without a release.
*/
class AdminSettings
{
    public const GROUP = 'admin';

    /** The safety check's kinds, and what each can do. */
    public const SAFETY_KINDS = [
        'contact'      => 'Contact details',
        'off_platform' => 'Moving to another app',
        'scam'         => 'Scam',
        'harassment'   => 'Harassment or threats',
        'sexual'       => 'Sexual content',
        'hate'         => 'Hate',
    ];

    public const SAFETY_ACTIONS = ['off' => 'Off', 'hide' => 'Hide', 'report' => 'Hide and Report'];

    /** config path => [label, type, min, max]. Types: int, text, long, list, json, choice. */
    public static function fields(): array
    {
        $fields = [
            'kaya.assistant.daily_limit'    => ['label' => 'Answers per person per day', 'type' => 'int', 'min' => 1, 'max' => 200],
            'kaya.assistant.quiet_hours'    => ['label' => 'Quiet hours after a team reply', 'type' => 'int', 'min' => 1, 'max' => 72],
            'kaya.assistant.timeout'        => ['label' => 'Seconds to wait for an answer', 'type' => 'int', 'min' => 5, 'max' => 60],
            'kaya.assistant.alert_after'    => ['label' => 'People with the same issue in an hour before an alert', 'type' => 'int', 'min' => 2, 'max' => 100],
            'kaya.assistant.model'          => ['label' => 'OmniRoute combo', 'type' => 'text', 'max' => 100],
            'kaya.assistant.fallback_model' => ['label' => 'Gemini model when OmniRoute is down', 'type' => 'text', 'max' => 100],
            'kaya.assistant.greeting'       => ['label' => 'Greeting', 'type' => 'text', 'max' => 300],
            'kaya.assistant.knowledge'      => ['label' => 'What KAYA Assistant knows', 'type' => 'long'],
            'kaya.assistant.menu'           => ['label' => 'Menu', 'type' => 'json'],

            'moderation.ai.hold_seconds'        => ['label' => 'Seconds a message waits for the check', 'type' => 'int', 'min' => 3, 'max' => 60],
            'moderation.ai.report_after_hidden' => ['label' => 'Contact attempts in a day before a report', 'type' => 'int', 'min' => 1, 'max' => 20],
            'moderation.ai.model'               => ['label' => 'OmniRoute combo', 'type' => 'text', 'max' => 100],
            'moderation.profanity'              => ['label' => 'Swear words', 'type' => 'list'],
            'moderation.off_platform_apps'      => ['label' => 'Other app names', 'type' => 'list'],
            'moderation.evasion_phrases'        => ['label' => 'Phrases for talking outside KAYA', 'type' => 'list'],
        ];

        foreach (array_keys(self::SAFETY_KINDS) as $kind) {
            $fields["moderation.ai.actions.{$kind}"] = ['label' => self::SAFETY_KINDS[$kind], 'type' => 'choice'];
        }

        return $fields;
    }

    /** Lays the saved values over the config. Called once at boot. */
    public static function apply(): void
    {
        try {
            $saved = SystemSetting::where('group', self::GROUP)->pluck('value', 'key');
        } catch (QueryException) {
            return;
        }

        $fields = self::fields();
        foreach ($saved as $key => $value) {
            if (! isset($fields[$key]) || $value === null) {
                continue;
            }
            config([$key => self::decode($fields[$key]['type'], $value)]);
        }
    }

    public static function set(string $key, mixed $value): void
    {
        $type = self::fields()[$key]['type'];
        $stored = match ($type) {
            'list', 'json' => json_encode(array_values(is_array($value) ? $value : []), JSON_UNESCAPED_UNICODE),
            default        => (string) $value,
        };
        if ($type === 'json') {
            $stored = json_encode($value, JSON_UNESCAPED_UNICODE);
        }

        SystemSetting::updateOrCreate(['key' => $key], ['value' => $stored, 'label' => self::fields()[$key]['label'], 'group' => self::GROUP]);
        config([$key => self::decode($type, $stored)]);
    }

    public static function forget(string $key): void
    {
        SystemSetting::where('key', $key)->where('group', self::GROUP)->delete();
    }

    private static function decode(string $type, string $value): mixed
    {
        return match ($type) {
            'int'          => (int) $value,
            'list', 'json' => json_decode($value, true) ?? [],
            default        => $value,
        };
    }

    /** A list setting typed one per line, cleaned. */
    public static function lines(?string $text): array
    {
        return array_values(array_unique(array_filter(array_map(
            fn ($line) => mb_strtolower(trim($line)),
            preg_split('/\R/', (string) $text),
        ), fn ($line) => $line !== '')));
    }
}
