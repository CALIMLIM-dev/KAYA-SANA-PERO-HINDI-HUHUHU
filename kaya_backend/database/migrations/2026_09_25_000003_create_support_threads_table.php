<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A way to talk to KAYA.

    Every other thread on this platform is between two users. There was no way
    to reach the people running it at all: somebody locked out by a rejected
    verification, charged for an application that vanished, or reporting
    something the report form does not cover had nowhere to go but the app
    store review page.

    One thread per account, not a ticket per problem. A ticket system needs
    subjects, statuses, assignment and a queue UI to be worth anything, and
    the whole of it exists to keep threads apart when there are thousands. At
    this size a person has one conversation with KAYA that continues, which is
    also what "chat to support" means to the person using it.

    Deliberately NOT the conversations table. That one is keyed on a pair of
    users with an employer seat and a worker seat, carries a job and a paid
    contact unlock, and is archived when work finishes. None of that is true
    here, and bending it to fit would put KAYA in somebody's inbox as an
    employer.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_threads', function (Blueprint $table) {
            $table->id();

            // One per account. The unique key is what makes "the thread" a
            // thing that can be spoken of at all.
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();

            // Sorting the admin queue. A thread nobody has answered for two
            // days matters more than one answered an hour ago, and neither is
            // findable by created_at.
            $table->timestamp('last_message_at')->nullable();

            $table->timestamps();
        });

        Schema::create('support_messages', function (Blueprint $table) {
            $table->id();

            $table->foreignId('support_thread_id')->constrained('support_threads')->cascadeOnDelete();

            // Who typed it. An administrator's own id, not a shared KAYA
            // account, so the audit trail names a person.
            $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();

            // Which side it came from. Not derived from sender_id: an admin
            // account can also be a user, and a deleted admin leaves a null
            // sender that still has to read as coming from KAYA.
            $table->boolean('from_admin')->default(false);

            $table->text('body');

            // Read by the other side. Null is the unread state, and the
            // badges on both ends count rows rather than keeping a tally -
            // a counter beside the rows it counts is a thing that drifts.
            $table->timestamp('read_at')->nullable();

            $table->timestamps();

            $table->index(['support_thread_id', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_messages');
        Schema::dropIfExists('support_threads');
    }
};
