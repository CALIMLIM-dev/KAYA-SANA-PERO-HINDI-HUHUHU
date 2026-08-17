<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * In-app notifications for end users.
 *
 * Named `user_notifications`, not `notifications`, on purpose: Laravel's own
 * database-notification channel owns a `notifications` table with a completely
 * different shape (uuid, notifiable_type, json data). Taking that name would
 * make the two mutually exclusive for no gain.
 *
 * The only notifications table that existed before this was
 * `admin_notifications`, which nothing has ever written to — so several
 * already-built flows (hire, invite, message) notified nobody.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('user_notifications')) {
            return;
        }

        Schema::create('user_notifications', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();

            /**
             * Which side of the marketplace this concerns.
             *
             * Stored at write time rather than derived at read time: the
             * sender always knows whether it is notifying someone as a worker
             * or as an employer, and a hybrid account holds both roles at
             * once, so deriving it later means re-deciding from the reference
             * on every read and getting it wrong for one of the two.
             */
            $table->enum('audience', ['worker', 'employer']);

            // Dotted event name, e.g. "application.accepted" — drives the icon
            // and the tap target in the app.
            $table->string('type', 60);

            $table->string('title');
            $table->text('body')->nullable();

            // What to open when tapped, e.g. ("job", 18) or ("application", 7).
            $table->string('reference_type', 40)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();

            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            // The unread badge counts on this.
            $table->index(['user_id', 'read_at']);
            // The list is always "mine, for this mode, newest first".
            $table->index(['user_id', 'audience', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_notifications');
    }
};
