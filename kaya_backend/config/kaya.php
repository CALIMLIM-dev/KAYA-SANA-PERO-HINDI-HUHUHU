<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Admin account
    |--------------------------------------------------------------------------
    | Credentials for the seeded admin user. Required in production — AdminSeeder
    | refuses to run without them rather than falling back to a known default.
    */

    'admin' => [
        'name'     => env('ADMIN_NAME', 'Admin'),
        'email'    => env('ADMIN_EMAIL'),
        'password' => env('ADMIN_PASSWORD'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Credits
    |--------------------------------------------------------------------------
    | What actions cost, and what every account is given each month.
    |
    | These numbers are set for Philippine local service work, not copied from
    | a marketplace priced in dollars. The anchor is that a worker here is
    | pricing a day of labour at roughly 400 to 650 pesos, and buys prepaid
    | load in 20 to 100 peso steps. A fee only works if it feels like sending
    | a few texts.
    |
    | At two credits an application and roughly two pesos a credit, applying
    | costs about four pesos against a job worth several hundred — under one
    | percent of a day's pay. That is high enough to stop someone applying to
    | everything without reading it, and far too low to stop someone applying
    | to work they actually want, which is the only balance that matters.
    |
    | Posting a job, receiving applications, and messaging after a hire are
    | free on purpose and are not listed here. Charging for access is how a
    | two sided marketplace dies: if employers cannot reach workers the
    | workers leave, and then the employers leave. Only advantage is charged.
    */

    /*
        Completion and reviewing, in days.

        Neither had a limit. A hire sat in 'accepted' forever if one side
        never confirmed - the worker could not be reviewed, the employer's
        card never cleared, and nothing on screen said why. And a review
        could be left at any point in the future, which is both untrue to
        the work and a way to hold somebody's rating hostage.

        Seven days to confirm: long enough for a job that ran over or a
        person who was off the app for a week, short enough that the other
        side is not stuck for a month. Past it the hire is closed as
        unsuccessful rather than assumed done - see CloseUnconfirmedHires.

        Seven to review as well, counted from completion. Thirty was picked
        off the top of my head and is out of step with what people actually
        use: Shopee gives seven days from delivery, Grab and foodpanda want
        it in the moment, Upwork and Airbnb allow fourteen for engagements
        that run for weeks. A KAYA job is one visit that ends the same day,
        so it belongs at the short end - and a rating written a month later
        is memory, not observation.
    */
    'completion' => [
        'auto_confirm_after_days' => (int) env('COMPLETION_AUTO_CONFIRM_DAYS', 7),
    ],

    'reviews' => [
        'window_days' => (int) env('REVIEW_WINDOW_DAYS', 7),
    ],

    'credits' => [

        /*
            What the currency is called on screen. A placeholder.

            Every identifier in the code — tables, columns, classes, routes —
            uses the neutral word "credit" on purpose, so this is the only
            place in the backend the display name appears, and the Flutter side
            has exactly one matching constant. Renaming is a two line change
            rather than a migration, which is why it was safe to pick one at
            all before anybody had decided.

            "Barya" is Filipino for loose change. It reads as a token rather
            than as money, which is the position to hold: these are not
            redeemable for cash and should never look like they are. Swap it
            for anything — the plural and the icon live here too.
        */
        'currency_name'        => env('CREDIT_NAME', 'Barya'),
        'currency_name_plural' => env('CREDIT_NAME_PLURAL', 'Barya'),

        // Applying to a job. Paid by the worker.
        'apply' => (int) env('CREDIT_COST_APPLY', 2),

        /*
            Inviting a worker directly. Paid by the employer.

            Matched to the application fee rather than set higher. An invite is
            the action that gets a quiet worker hired, so taxing it heavily
            works against the thing the marketplace exists to produce — and the
            employer is already about to pay that worker several hundred pesos.
        */
        'invite' => (int) env('CREDIT_COST_INVITE', 2),

        // Unlocking a worker's contact details, once, forever.
        'unlock' => (int) env('CREDIT_COST_UNLOCK', 10),

        /*
            The free monthly grant, and the floor under the whole design.

            Twenty credits is ten applications a month at no cost. A worker who
            runs dry and cannot afford to top up stops opening the app, and
            enough of those and there is nobody left to hire — so this is not
            generosity, it is the supply side staying alive.

            One grant per ACCOUNT, not per profile, or creating a second
            profile becomes worth free money.
        */
        'monthly_grant' => (int) env('CREDIT_MONTHLY_GRANT', 20),

        // Given once when an account first gets a wallet, so a new user can
        // act immediately instead of meeting a paywall on their first day.
        'signup_grant' => (int) env('CREDIT_SIGNUP_GRANT', 20),

        /*
            How long after applying a withdrawal still refunds.

            Beyond this window, "apply, get seen, withdraw" would be a free
            application. Within it, an honest misclick is not punished.
        */
        'withdraw_refund_minutes' => (int) env('CREDIT_WITHDRAW_REFUND_MINUTES', 60),
    ],

];
