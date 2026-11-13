<?php

namespace App\Contracts;

/*
    Asks Google Play whether a purchase really happened.

    GooglePlayVerifier talks to Google; tests bind a fake. The app's word
    is never enough: a package is credited only when this says purchased.
*/
interface PlayPurchaseVerifier
{
    /**
     * @return array{product_id: string, purchased: bool, account: ?string, order_id: ?string}|null
     *         null when Google does not know the token or cannot be reached
     */
    public function verify(string $productId, string $purchaseToken): ?array;

    /** Tells Google the purchase was delivered, so it is not refunded after 3 days. */
    public function acknowledge(string $productId, string $purchaseToken): void;
}
