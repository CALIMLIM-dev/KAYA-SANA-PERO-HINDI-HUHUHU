<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A Barya reward already paid for a badge. See the migration. */
class BadgeReward extends Model
{
    protected $fillable = ['user_id', 'code', 'side', 'amount', 'credit_transaction_id'];

    public function user() { return $this->belongsTo(User::class); }
    public function transaction() { return $this->belongsTo(CreditTransaction::class, 'credit_transaction_id'); }
}
