<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
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

        foreach ($values as $key => $value) {
            SystemSetting::where('key', $key)->update(['value' => $value]);
        }

        // Checkboxes that were unchecked don't get sent at all — set those to '0'
        SystemSetting::whereNotIn('key', array_keys($values))
            ->where('group', '!=', 'general')
            ->update(['value' => '0']);

        return back()->with('success', 'System configuration updated.');
    }
}
