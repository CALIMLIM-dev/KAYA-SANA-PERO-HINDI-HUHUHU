<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\User;
use App\Services\MessageFilter;
use App\Services\SafetyCheck;
use App\Support\AdminSettings;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/*
    The AI Safety Check, configurable: on or off, what each kind does (off,
    hide, or hide and report), how long a message waits for the check, the
    word lists behind the first filter, what it did this week and who it
    stopped most - and Try a Message, to see a verdict without a real user.

    It shows kinds, places and counts, never the words of a hidden message;
    nothing here opens anybody's chat.
*/
class SafetyController extends Controller
{
    private const TABS = ['overview' => 'Overview', 'settings' => 'Settings', 'words' => 'Word Lists'];

    public function index(Request $request)
    {
        $tab = array_key_exists($request->get('tab'), self::TABS) ? $request->get('tab') : 'overview';

        $week = DB::table('assistant_stats')
            ->where('day', '>=', now('Asia/Manila')->subDays(6)->toDateString())
            ->where('metric', 'like', 'safety:%')
            ->get();

        $byKind = collect(AdminSettings::SAFETY_KINDS)->map(fn ($label, $kind) => [
            'label' => $label,
            'count' => (int) $week->where('metric', "safety:hidden:{$kind}")->sum('count'),
        ]);

        $offenders = $week->filter(fn ($r) => str_starts_with($r->metric, 'safety:hidden_by:'))
            ->groupBy(fn ($r) => (int) substr($r->metric, strlen('safety:hidden_by:')))
            ->map(fn ($rows) => (int) $rows->sum('count'))
            ->sortDesc()
            ->take(10);
        $people = User::whereIn('id', $offenders->keys())->get(['id', 'name'])->keyBy('id');

        return view('admin.safety.index', [
            'tabs'      => self::TABS,
            'tab'       => $tab,
            'enabled'   => SafetyCheck::enabled(),
            'today'     => SafetyCheck::todayStats(),
            'byKind'    => $byKind,
            'weekTotal' => [
                'checked'  => (int) $week->where('metric', 'safety:checked')->sum('count'),
                'hidden'   => (int) $week->where('metric', 'safety:hidden')->sum('count'),
                'reported' => (int) $week->where('metric', 'safety:reported')->sum('count'),
            ],
            'offenders' => $offenders,
            'people'    => $people,
            'fields'    => AdminSettings::fields(),
        ]);
    }

    public function saveSettings(Request $request)
    {
        $rules = [
            'hold_seconds'        => ['required', 'integer', 'min:3', 'max:60'],
            'report_after_hidden' => ['required', 'integer', 'min:1', 'max:20'],
            'model'               => ['required', 'string', 'max:100'],
        ];
        foreach (array_keys(AdminSettings::SAFETY_KINDS) as $kind) {
            $rules["actions.{$kind}"] = ['required', 'in:' . implode(',', array_keys(AdminSettings::SAFETY_ACTIONS))];
        }
        $data = $request->validate($rules);

        AdminSettings::set('moderation.ai.hold_seconds', $data['hold_seconds']);
        AdminSettings::set('moderation.ai.report_after_hidden', $data['report_after_hidden']);
        AdminSettings::set('moderation.ai.model', $data['model']);
        foreach ($data['actions'] as $kind => $action) {
            AdminSettings::set("moderation.ai.actions.{$kind}", $action);
        }
        AdminAction::record('safety.settings', 'setting', null, 'Changed the Safety Check settings');

        return back()->with('success', 'Settings saved.');
    }

    public function saveWords(Request $request)
    {
        $lists = ['moderation.profanity' => 'profanity', 'moderation.off_platform_apps' => 'apps', 'moderation.evasion_phrases' => 'phrases'];

        if ($request->boolean('reset')) {
            foreach (array_keys($lists) as $key) {
                AdminSettings::forget($key);
            }

            return back()->with('success', 'Word lists are back to the default. Reload to see them.');
        }

        $request->validate(['profanity' => ['nullable', 'string', 'max:20000'], 'apps' => ['nullable', 'string', 'max:5000'], 'phrases' => ['nullable', 'string', 'max:20000']]);
        foreach ($lists as $key => $field) {
            AdminSettings::set($key, AdminSettings::lines($request->input($field)));
        }
        AdminAction::record('safety.words', 'setting', null, 'Edited the word filter lists');

        return back()->with('success', 'Word lists saved.');
    }

    /*
        Try a Message: the verdict both filters would give, without a real
        user anywhere near it. Shown once, not stored.
    */
    public function tryMessage(Request $request, SafetyCheck $check, MessageFilter $filter)
    {
        $text = (string) $request->validate(['text' => ['required', 'string', 'max:500']])['text'];

        $words = $filter->inspect($text);
        $verdict = $check->check($text);

        return redirect()->route('admin.safety.index')->with('tried', [
            'text'    => $text,
            'masked'  => $words['text'] ?? $text,
            'verdict' => $verdict,
        ]);
    }
}
