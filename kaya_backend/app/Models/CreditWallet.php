<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * One balance per account.
 *
 * Deliberately thin. Nothing here spends or grants — that is CreditLedger's
 * job, and it is the only thing allowed to move `balance`, so there is exactly
 * one place to read when the number is wrong.
 */
class CreditWallet extends Model
{
    protected $fillable = ['user_id', 'balance', 'last_grant_period'];

    protected $casts = [
        // Integer, never decimal. A credit is a unit of entitlement and half
        // of one cannot exist; this also keeps it serialising as a number
        // rather than the string a decimal cast produces.
        'balance' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(CreditTransaction::class, 'user_id', 'user_id');
    }
}
