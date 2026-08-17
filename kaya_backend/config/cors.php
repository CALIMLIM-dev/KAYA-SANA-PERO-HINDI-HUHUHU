<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    | Origins come from CORS_ALLOWED_ORIGINS (comma-separated). When it is unset
    | we fall back to '*', which is fine for local development but must never be
    | the case in production — set the variable on the deployed environment.
    |
    | Note: native mobile apps do not send an Origin header and are unaffected by
    | CORS. This only governs Flutter web and any browser-based client.
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_values(array_filter(
        array_map('trim', explode(',', (string) env('CORS_ALLOWED_ORIGINS', '')))
    )) ?: ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
