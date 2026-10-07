<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    What a report rests on, and the other side of it.

    The panel: "Provide substantial supporting evidence and relevant details
    when submitting or processing reports involving either party to
    facilitate proper evaluation and resolution."

    evidence   up to three photos the reporter attached, on the private disk
    snapshot   a copy of the reported message, post, job or profile as it was
               when reported, so deleting it afterwards destroys nothing
    response   the reported person's side, once, before a decision
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->json('evidence')->nullable()->after('description');
            $table->json('snapshot')->nullable()->after('evidence');
            $table->text('response')->nullable()->after('snapshot');
            $table->timestamp('responded_at')->nullable()->after('response');
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropColumn(['evidence', 'snapshot', 'response', 'responded_at']);
        });
    }
};
