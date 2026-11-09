<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

// Closed reports read "Violation given", as the panel now names it.
return new class extends Migration
{
    public function up(): void
    {
        DB::table('reports')->where('resolution_note', 'like', 'Violation found: %')->get(['id', 'resolution_note'])
            ->each(fn ($r) => DB::table('reports')->where('id', $r->id)->update([
                'resolution_note' => 'Violation given: ' . substr($r->resolution_note, strlen('Violation found: ')),
            ]));
    }

    public function down(): void
    {
    }
};
