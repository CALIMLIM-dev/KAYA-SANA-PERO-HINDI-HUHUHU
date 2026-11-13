<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One person blocking another. See App\Support\Blocks for how it is read. */
class UserBlock extends Model
{
    protected $fillable = ['blocker_id', 'blocked_id'];

    protected $casts = ['blocker_id' => 'integer', 'blocked_id' => 'integer'];

    public function blocked()
    {
        return $this->belongsTo(User::class, 'blocked_id');
    }
}
