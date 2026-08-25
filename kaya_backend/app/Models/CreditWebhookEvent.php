<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Every webhook that arrived, recorded once.
 *
 * The unique index on provider and event id means a redelivery cannot be
 * written twice. This is a log rather than the safety mechanism though — the
 * guarantee that credits are granted once lives in the payment status update,
 * because the same payment can arrive under a different event id.
 */
class CreditWebhookEvent extends Model
{
    protected $fillable = [
        'provider', 'provider_event_id', 'event_type', 'payload', 'received_at',
    ];

    protected $casts = [
        'payload' => 'array',
        'received_at' => 'datetime',
    ];
}
