<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The line for a KAYA agent, and the hand-over between the assistant and
    a person.

    queue_since: when this person first asked for an agent; their place in
    line. Back to Assistant keeps it until queue_saved_until, so asking
    again soon puts them back where they were, not at the end.
    agent_joined_at: when an agent took the chat ("Ana joined").
    summary: two lines for the agent, written at the hand-off.
    issue: what they picked in the assistant's menu.
    support_messages.kind: 'event' for the lines between the two sides
    ("Ana from KAYA joined the chat") rather than something either typed.
    users.support_available: an admin taking support chats right now; with
    nobody available the person is told the team is offline.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_threads', function (Blueprint $table) {
            $table->dateTime('queue_since')->nullable();
            $table->dateTime('queue_saved_until')->nullable();
            $table->dateTime('agent_joined_at')->nullable();
            $table->text('summary')->nullable();
            $table->string('issue', 60)->nullable();
        });

        Schema::table('support_messages', function (Blueprint $table) {
            $table->string('kind', 10)->nullable();
            // Buttons on an assistant line: choices to tap, and screens to open.
            $table->json('payload')->nullable();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->boolean('support_available')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('support_threads', function (Blueprint $table) {
            $table->dropColumn(['queue_since', 'queue_saved_until', 'agent_joined_at', 'summary', 'issue']);
        });
        Schema::table('support_messages', function (Blueprint $table) {
            $table->dropColumn(['kind', 'payload']);
        });
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('support_available');
        });
    }
};
