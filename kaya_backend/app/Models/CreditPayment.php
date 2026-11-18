<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One attempt to buy credits.
 *
 * The price and the credit count are copied from the package at that moment. Nothing later reads the
 * package again — a price edited next month must not change what somebody was
 * charged today, and a deactivated package must still explain an old payment.
 */
class CreditPayment extends Model
{
    public const STATUS_PENDING = 'pending';
    public const STATUS_PAID = 'paid';
    public const STATUS_FAILED = 'failed';

    /** How it was paid. */
    public const METHOD_FREE = 'free';
    public const METHOD_GCASH = 'gcash';

    /** A GCash top-up, after an admin compares it with the GCash history. */
    public const CHECK_UNCHECKED = 'unchecked';
    public const CHECK_RECEIVED = 'received';
    public const CHECK_NOT_RECEIVED = 'not_received';

    protected $fillable = [
        'user_id', 'reference', 'credit_package_id',
        'credits', 'amount_centavos', 'status',
        'provider_session_id', 'paid_at', 'credit_transaction_id',
        'method', 'gcash_ref', 'proof_path', 'check_status', 'checked_by', 'checked_at', 'check_note',
    ];

    protected $casts = [
        'credits' => 'integer',
        'amount_centavos' => 'integer',
        'paid_at' => 'datetime',
        'checked_at' => 'datetime',
    ];

    protected $hidden = ['proof_path'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(CreditPackage::class, 'credit_package_id');
    }

    public function checker(): BelongsTo
    {
        return $this->belongsTo(User::class, 'checked_by');
    }

    public function transaction(): BelongsTo
    {
        return $this->belongsTo(CreditTransaction::class, 'credit_transaction_id');
    }

    /** The number printed on the receipt. */
    public function receiptNo(): string
    {
        return 'KAYA-' . str_pad((string) $this->id, 6, '0', STR_PAD_LEFT);
    }

    public function amountPhp(): float
    {
        return $this->amount_centavos / 100;
    }
}
