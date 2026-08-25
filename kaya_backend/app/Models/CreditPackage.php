<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * What a top-up costs.
 *
 * Price and credit count are read from here at checkout and never from the
 * request, so a tampered payload cannot buy 500 credits for one peso.
 */
class CreditPackage extends Model
{
    protected $fillable = ['name', 'credits', 'amount_centavos', 'is_active', 'sort_order'];

    protected $casts = [
        'credits' => 'integer',
        // Centavos, matching what PayMongo expects, so nothing multiplies by
        // 100 on the way out and no rounding error can creep in.
        'amount_centavos' => 'integer',
        'is_active' => 'boolean',
    ];

    /** Pesos, for display only — never for arithmetic. */
    public function amountPhp(): float
    {
        return $this->amount_centavos / 100;
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true)->orderBy('sort_order');
    }
}
