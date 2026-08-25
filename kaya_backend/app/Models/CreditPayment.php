<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One attempt to buy credits.
 *
 * The row is written before PayMongo is called, with the price and the credit
 * count copied from the package at that moment. Nothing later reads the
 * package again — a price edited next month must not change what somebody was
 * charged today, and a deactivated package must still explain an old payment.
 */
class CreditPayment extends Model
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_PAID = 'paid';
    public const STATUS_FAILED = 'failed';

    protected $fillable = [
        'user_id', 'reference', 'credit_package_id',
        'credits', 'amount_centavos', 'status',
        'provider_session_id', 'paid_at', 'credit_transaction_id',
    ];

    protected $casts = [
        'credits' => 'integer',
        'amount_centavos' => 'integer',
        'paid_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(CreditPackage::class, 'credit_package_id');
    }

    public function amountPhp(): float
    {
        return $this->amount_centavos / 100;
    }
}
