<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Support\Pricing;
use Illuminate\Http\Request;

/*
    Prices, editable.

    This page used to render whatever rows sat in system_settings as
    checkboxes, and nothing in the app read them, so every switch was
    decoration. Now it is the pricing table: the numbers config/kaya.php
    documents, changeable without a deploy, each change written to the
    audit log with the old and new value.
*/
class SettingsController extends Controller
{
    public function index()
    {
        return view('admin.settings.index', ['fields' => Pricing::current()]);
    }

    public function update(Request $request)
    {
        $rules = [];
        foreach (Pricing::FIELDS as $key => $field) {
            $rules[Pricing::formName($key)] = ['required', 'integer', "min:{$field['min']}", "max:{$field['max']}"];
        }

        $data = $request->validate($rules);

        $changed = [];
        foreach ($data as $name => $value) {
            $key = Pricing::fromFormName($name);
            $was = (int) config($key);

            if ($was === (int) $value) {
                continue;
            }

            Pricing::set($key, (int) $value);
            $changed[Pricing::FIELDS[$key]['label']] = ['from' => $was, 'to' => (int) $value];
        }

        if ($changed === []) {
            return back()->with('success', 'Nothing changed.');
        }

        AdminAction::record(
            'settings.pricing', 'setting', null,
            'Changed ' . collect($changed)->map(fn ($c, $label) => "{$label} {$c['from']} to {$c['to']}")->join(', '),
            $changed,
        );

        return back()->with('success', count($changed) . ' price(s) updated. The app picks them up on its next refresh.');
    }
}
