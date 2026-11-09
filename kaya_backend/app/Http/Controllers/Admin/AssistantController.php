<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\AssistantFeedback;
use App\Models\AssistantLesson;
use App\Models\KnownIssue;
use App\Models\SupportThread;
use App\Services\KayaAssistant;
use App\Services\SupportFlow;
use App\Support\AdminSettings;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

/*
    Everything about KAYA Assistant in one place, editable by a platform
    admin: on or off, its limits and model, the greeting, what it knows, the
    guided menu, known-issue notices (with alerts when many people pick the
    same issue at once), and the answers people reported - with a box to
    teach it a better one.
*/
class AssistantController extends Controller
{
    private const TABS = ['overview' => 'Overview', 'settings' => 'Settings', 'menu' => 'Menu', 'help' => 'Help Text', 'issues' => 'Known Issues', 'answers' => 'Reported Answers'];

    public function index(Request $request)
    {
        $tab = array_key_exists($request->get('tab'), self::TABS) ? $request->get('tab') : 'overview';

        return view('admin.assistant.index', [
            'tabs'      => self::TABS,
            'tab'       => $tab,
            'enabled'   => KayaAssistant::enabled(),
            'today'     => KayaAssistant::todayStats(),
            'line'      => SupportThread::line()->count(),
            'alerts'    => $this->alerts(),
            'fields'    => AdminSettings::fields(),
            'menu'      => SupportFlow::menu(),
            'menuEdited' => is_array(config('kaya.assistant.menu')) && config('kaya.assistant.menu') !== [],
            'knowledge' => (string) (config('kaya.assistant.knowledge') ?: @file_get_contents(resource_path('assistant/knowledge.md'))),
            'knowledgeEdited' => filled(config('kaya.assistant.knowledge')),
            'issues'    => KnownIssue::with('createdBy:id,name')->latest('id')->take(30)->get(),
            'feedback'  => AssistantFeedback::with('user:id,name')->latest('id')->take(30)->get(),
            'lessons'   => AssistantLesson::latest('id')->take(30)->get(),
            'topics'    => collect(SupportFlow::menu())->map(fn ($t) => $t['label'])->all(),
        ]);
    }

    /*
        The same issue picked by many people within the hour: probably one
        problem hitting everybody. Counted by SupportFlow; nothing is posted
        until an admin says so.
    */
    private function alerts(): array
    {
        $menu = SupportFlow::menu();
        $hours = [now('Asia/Manila')->format('H'), now('Asia/Manila')->subHour()->format('H')];

        return DB::table('assistant_stats')
            ->where('day', now('Asia/Manila')->toDateString())
            ->where('metric', 'like', 'issue:%')
            ->get()
            ->filter(fn ($row) => in_array(substr($row->metric, -2), $hours, true))
            ->groupBy(fn ($row) => substr($row->metric, 6, -3))
            ->map(fn ($rows, $key) => [
                'key'   => $key,
                'count' => $rows->sum('count'),
                'topic' => explode('.', $key)[0],
                'label' => $menu[explode('.', $key)[0]]['issues'][explode('.', $key)[1] ?? '']['label'] ?? $key,
            ])
            ->filter(fn ($a) => $a['count'] >= (int) config('kaya.assistant.alert_after'))
            ->sortByDesc('count')
            ->values()
            ->all();
    }

    public function toggle()
    {
        $on = ! KayaAssistant::enabled();
        KayaAssistant::setEnabled($on);
        AdminAction::record('assistant.toggled', 'setting', null, 'Turned KAYA Assistant ' . ($on ? 'on' : 'off'));

        return back()->with('success', 'KAYA Assistant is ' . ($on ? 'on.' : 'off. The team answers everything.'));
    }

    public function saveSettings(Request $request)
    {
        $keys = ['kaya.assistant.daily_limit', 'kaya.assistant.quiet_hours', 'kaya.assistant.timeout', 'kaya.assistant.alert_after',
            'kaya.assistant.model', 'kaya.assistant.fallback_model', 'kaya.assistant.greeting'];
        $fields = AdminSettings::fields();

        $rules = [];
        foreach ($keys as $key) {
            $f = $fields[$key];
            $rules[str_replace('.', '__', $key)] = $f['type'] === 'int'
                ? ['required', 'integer', "min:{$f['min']}", "max:{$f['max']}"]
                : ['required', 'string', 'max:' . ($f['max'] ?? 300)];
        }
        $data = $request->validate($rules);

        foreach ($keys as $key) {
            AdminSettings::set($key, $data[str_replace('.', '__', $key)]);
        }
        AdminAction::record('assistant.settings', 'setting', null, 'Changed KAYA Assistant settings');

        return back()->with('success', 'Settings saved.');
    }

    public function saveKnowledge(Request $request)
    {
        if ($request->boolean('reset')) {
            AdminSettings::forget('kaya.assistant.knowledge');
            config(['kaya.assistant.knowledge' => null]);

            return back()->with('success', 'Help text is back to the default.');
        }

        $data = $request->validate(['knowledge' => ['required', 'string', 'max:30000']]);
        AdminSettings::set('kaya.assistant.knowledge', trim($data['knowledge']));
        AdminAction::record('assistant.knowledge', 'setting', null, 'Edited what KAYA Assistant knows');

        return back()->with('success', 'Help text saved. KAYA Assistant uses it from the next question.');
    }

    /*
        The menu: each issue's button and answer can be changed or removed,
        and new issues added under a topic. Saved whole; Reset brings back the
        default from resources/assistant/flow.php.
    */
    public function saveMenu(Request $request)
    {
        if ($request->boolean('reset')) {
            AdminSettings::forget('kaya.assistant.menu');
            config(['kaya.assistant.menu' => null]);

            return back()->with('success', 'Menu is back to the default.');
        }

        $request->validate([
            'issues.*.*.label'  => ['nullable', 'string', 'max:80'],
            'issues.*.*.answer' => ['nullable', 'string', 'max:2000'],
            'new.*.label'       => ['nullable', 'string', 'max:80'],
            'new.*.answer'      => ['nullable', 'string', 'max:2000'],
        ]);

        $menu = SupportFlow::menu();
        foreach ($menu as $topic => &$t) {
            foreach ($t['issues'] as $key => $issue) {
                $edit = $request->input("issues.{$topic}.{$key}");
                if (! $edit) {
                    continue;
                }
                if (! empty($edit['remove'])) {
                    unset($t['issues'][$key]);
                    continue;
                }
                $t['issues'][$key]['label'] = trim($edit['label'] ?? $issue['label']) ?: $issue['label'];
                $t['issues'][$key]['answer'] = trim($edit['answer'] ?? $issue['answer']) ?: $issue['answer'];
            }

            $new = $request->input("new.{$topic}");
            if (filled($new['label'] ?? null) && filled($new['answer'] ?? null)) {
                $t['issues']['custom_' . substr(md5($new['label'] . microtime()), 0, 8)] = [
                    'label' => trim($new['label']), 'answer' => trim($new['answer']), 'actions' => [],
                ];
            }
        }
        unset($t);

        AdminSettings::set('kaya.assistant.menu', $menu);
        AdminAction::record('assistant.menu', 'setting', null, 'Edited the KAYA Assistant menu');

        return back()->with('success', 'Menu saved.');
    }

    public function postIssue(Request $request)
    {
        $data = $request->validate([
            'text'  => ['required', 'string', 'max:300'],
            'topic' => ['nullable', 'string', 'max:30'],
        ]);

        KnownIssue::create(['text' => trim($data['text']), 'topic' => $data['topic'] ?: null, 'active' => true, 'created_by' => Auth::id()]);
        AdminAction::record('assistant.known_issue', 'setting', null, 'Posted a known issue: ' . $data['text']);

        return redirect()->route('admin.assistant.index', ['tab' => 'issues'])->with('success', 'Posted. KAYA Assistant tells everyone who asks about it.');
    }

    public function endIssue(KnownIssue $issue)
    {
        $issue->forceFill(['active' => false])->save();

        return back()->with('success', 'Notice taken down.');
    }

    /** A notice drafted by the AI for an alert, to edit and post. Free fallback when no model answers. */
    public function draftIssue(Request $request, KayaAssistant $assistant)
    {
        $label = (string) $request->validate(['label' => ['required', 'string', 'max:120']])['label'];
        $draft = $assistant->draftNotice($label)
            ?? "We know some people are having a problem with: {$label}. The team is working on it.";

        return redirect()->route('admin.assistant.index', ['tab' => 'issues', 'topic' => $request->input('topic')])
            ->with('draft', $draft);
    }

    /** Teach it: a better answer for a reported one. */
    public function teach(Request $request, AssistantFeedback $feedback)
    {
        $data = $request->validate(['answer' => ['required', 'string', 'max:2000']]);

        AssistantLesson::create([
            'question'   => (string) ($feedback->question ?: 'The question before: ' . $feedback->answer),
            'answer'     => trim($data['answer']),
            'created_by' => Auth::id(),
        ]);
        $feedback->delete();

        return back()->with('success', 'Saved. KAYA Assistant uses your answer from now on.');
    }

    public function forgetLesson(AssistantLesson $lesson)
    {
        $lesson->delete();

        return back()->with('success', 'Removed.');
    }
}
