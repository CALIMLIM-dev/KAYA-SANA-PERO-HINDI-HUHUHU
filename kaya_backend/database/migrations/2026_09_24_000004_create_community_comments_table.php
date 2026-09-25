<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The board becomes a thread.

    A notice with no way to answer it in the open sends every question into a
    private message, which means the same question is asked twenty times and
    answered twenty times, and nobody reading the post can see that it was
    already asked. "Magkano po?" and "May available pa po ba?" are public
    questions with public answers.

    Deliberately flat. No replies to replies: a job board thread is a handful
    of questions under a notice, and a tree would need indentation, collapsing
    and a depth limit to hold three comments.

    A comment is never deleted, the same rule the post itself follows. It is
    marked removed and keeps its text, so a report has something to point at.
    There is no approval queue for comments - the post was read before it went
    up, and holding every "magkano po" for an administrator would make the
    thread unusable - so they go through the same filter chat does, and an
    administrator can take one down afterwards.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_comments', function (Blueprint $table) {
            $table->id();

            $table->foreignId('community_post_id')->constrained('community_posts')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();

            $table->string('body', 500);

            // live | removed. A string rather than an enum, matching the post.
            $table->string('status', 20)->default('live');

            $table->string('removed_reason')->nullable();
            $table->foreignId('removed_by')->nullable()->constrained('users')->nullOnDelete();

            $table->timestamps();

            // "What is under this post", which is the only question asked.
            $table->index(['community_post_id', 'status', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_comments');
    }
};
