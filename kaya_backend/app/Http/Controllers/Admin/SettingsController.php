<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\SystemSetting;
use Illuminate\Http\Request;

class SettingsController extends Controller
{
    public function index()
    {
        $settings = SystemSetting::all()->groupBy('group');

        return view('admin.settings.index', compact('settings'));
    }

    public function update(Request $request)
    {
        $values = $request->except('_token');

        // What changed, before it changes, so the log can say old and new.
        $before = SystemSetting::pluck('value', 'key');

        foreach ($values as $key => $value) {
            SystemSetting::where('key', $key)->update(['value' => $value]);
        }

        // Checkboxes that were unchecked don't get sent at all — set those to '0'
        SystemSetting::whereNotIn('key', array_keys($values))
            ->where('group', '!=', 'general')
            ->update(['value' => '0']);

        $changed = SystemSetting::pluck('value', 'key')
            ->filter(fn ($value, $key) => (string) $value !== (string) ($before[$key] ?? ''))
            ->map(fn ($value, $key) => ['from' => $before[$key] ?? null, 'to' => $value]);

        if ($changed->isNotEmpty()) {
            AdminAction::record(
                'settings.updated', 'setting', null,
                'Changed ' . $changed->keys()->map(fn ($k) => str_replace('_', ' ', $k))->join(', '),
                $changed->all(),
            );
        }

        return back()->with('success', 'System configuration updated.');
    }
}
