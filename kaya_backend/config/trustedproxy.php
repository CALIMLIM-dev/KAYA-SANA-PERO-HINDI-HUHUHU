<?php

/*
    Which machines may tell KAYA a client's real address.

    Only these can set X-Forwarded-For; from anywhere else the header is
    ignored and the connecting address is used. The default is this server
    itself, which is where nginx forwards from. If a CDN or load balancer is
    put in front, list its addresses in TRUSTED_PROXIES (comma separated).

    '*' is refused on purpose and falls back to the default: it lets anyone
    choose the address every rate limit counts, which is how login and
    reset-code limits could be reset with a made-up header. An old .env
    with TRUSTED_PROXIES=* is therefore safe without being edited.
*/
$proxies = trim((string) env('TRUSTED_PROXIES', ''));

return [
    'proxies' => in_array($proxies, ['', '*', '**'], true) ? '127.0.0.1,::1' : $proxies,
];
