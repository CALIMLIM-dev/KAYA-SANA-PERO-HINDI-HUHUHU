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
    protected $fillable = ['name', 'credits', 'amount_centavos', 'audience', 'is_active', 'sort_order'];

    public const AUDIENCE_ALL = 'all';
    public const AUDIENCE_INDIVIDUAL = 'individual';
    public const AUDIENCE_BUSINESS = 'business';

    /*
        The bundles one account may buy.

        Business tiers are larger and cheaper per credit, and are shown only
        to a verified company. Offering them to everyone would make the
        individual tiers pointless, since nothing would stop a single worker
        buying 3,500 credits at ₱0.80 instead of 25 at ₱2.00 — and the
        discount exists for volume, not for whoever scrolls furthest.

        Unverified and individual accounts see the same list they see today.
    */
    public function scopeForAudience($query, bool $isVerifiedBusiness)
    {
        return $isVerifiedBusiness
            ? $query->whereIn('audience', [self::AUDIENCE_ALL, self::AUDIENCE_BUSINESS])
            : $query->whereIn('audience', [self::AUDIENCE_ALL, self::AUDIENCE_INDIVIDUAL]);
    }

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
