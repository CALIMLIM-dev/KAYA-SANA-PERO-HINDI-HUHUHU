<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A KAYA Assistant answer somebody reported with its feedback button.

    Support chats are erased when the person leaves, so the report keeps its
    own copy of the question and the answer, and which model wrote it, for
    the team to read on the Support page.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('assistant_feedback', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('message_id')->nullable()->index();
            $table->text('question')->nullable();
            $table->text('answer');
            $table->string('model', 100)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assistant_feedback');
    }
};
