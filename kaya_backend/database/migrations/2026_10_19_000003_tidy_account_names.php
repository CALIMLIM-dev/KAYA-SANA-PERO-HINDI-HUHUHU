<?php

use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    Every existing name, tidied once the way new ones are on save: each word
    capitalised, and "N/A" in the middle name or suffix taken out. See
    User::tidyNamePart. Written through the query builder so nothing else on
    the account is touched.
*/
return new class extends Migration
{
    public function up(): void
    {
        DB::table('users')->whereNull('deleted_at')
            ->where(fn ($q) => $q->whereNull('user_type')->orWhere('user_type', '!=', 'admin'))
            ->orderBy('id')
            ->get(['id', 'name', 'first_name', 'middle_name', 'last_name', 'suffix'])
            ->each(function ($row) {
                $parts = [];
                foreach (['first_name', 'middle_name', 'last_name', 'suffix'] as $part) {
                    $parts[$part] = User::tidyNamePart($part, $row->{$part});
                }

                $name = blank($parts['first_name']) && blank($parts['last_name'])
                    ? (filled($row->name) ? User::titleCase($row->name) : $row->name)
                    : User::composeName($parts['first_name'], $parts['middle_name'], $parts['last_name'], $parts['suffix']);

                $changed = $parts + ['name' => $name];
                if ($changed != (array) collect((array) $row)->only(array_keys($changed))->all()) {
                    DB::table('users')->where('id', $row->id)->update($changed);
                }
            });
    }

    public function down(): void
    {
        // Nothing to undo: the old spellings were not kept.
    }
};
