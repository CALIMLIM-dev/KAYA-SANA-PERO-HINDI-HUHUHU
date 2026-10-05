<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
     | The OAuth Web client ID that Google ID tokens must be issued for.
     |
     | Not a secret — it ships inside the Android app and is visible to anyone
     | who unpacks the APK. It matters because it is the audience every incoming
     | token is checked against, which is what stops a token minted for some
     | other Google application from being accepted here.
     |
     | Must be the *Web application* client ID, not the Android one. Android
     | clients cannot mint ID tokens; the mobile SDK asks for a token whose
     | audience is the web client, which is why both exist.
     */
    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
    ],

    /*
     | SMS, for phone verification.
     |
     | Unset until an account exists, and that is handled honestly: SmsSender
     | refuses, the endpoint answers 503, and the app says phone verification
     | is unavailable. The screen used to fake the send instead and accept any
     | six digits.
     |
     | Semaphore is the Philippine default — credits without a subscription and
     | no sender-ID paperwork to begin. A registered sender name is required
     | for custom branding; without one they send as SEMAPHORE.
     */
    'semaphore' => [
        'key'         => env('SEMAPHORE_API_KEY'),
        'sender_name' => env('SEMAPHORE_SENDER_NAME', 'SEMAPHORE'),
    ],

    /*
     | Road routing for the live tracking map.
     |
     | Neither option is a paid mapping API.
     |
     | 'osrm' is the default because it needs no key and works the moment the
     | code is deployed. It is a public demo server, so it is rate-limited and
     | carries no uptime promise — fine for development, a gamble on demo day.
     |
     | 'ors' is OpenRouteService. The key is free (2,000 routes a day), but it
     | is a real supported tier rather than a demo box, which is what you want
     | when a panel is watching. Set ROUTING_PROVIDER=ors and ORS_API_KEY to
     | switch; nothing else changes.
     |
     | If routing fails either way, the map falls back to the straight dashed
     | line it drew before.
     */
    'routing' => [
        'provider' => env('ROUTING_PROVIDER', 'osrm'),
        'osrm_url' => env('OSRM_URL', 'https://router.project-osrm.org'),
        'ors_key'  => env('ORS_API_KEY'),
    ],

];
