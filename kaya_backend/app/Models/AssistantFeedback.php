<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A KAYA Assistant answer somebody reported. See the migration. */
class AssistantFeedback extends Model
{
    protected $table = 'assistant_feedback';

    protected $fillable = ['user_id', 'message_id', 'question', 'answer', 'model'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
