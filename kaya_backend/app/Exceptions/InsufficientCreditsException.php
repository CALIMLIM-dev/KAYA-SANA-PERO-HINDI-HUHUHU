<?php

namespace App\Exceptions;

use Exception;

/**
 * The balance will not cover what was asked for.
 *
 * Carries the two numbers the client needs to say something useful — how many
 * were required and how many are held — so the app can offer "top up to apply"
 * rather than a bare failure.
 *
 * Rendered as 402 Payment Required. 402 is used nowhere else in this API,
 * whereas 422 already carries dozens of meanings and its handler in the client
 * reaches for a validation errors bag first, which would surface the wrong
 * string entirely.
 */
class InsufficientCreditsException extends Exception
{
    public function __construct(
        public readonly int $required,
        public readonly int $balance,
    ) {
        parent::__construct(sprintf(
            'You need %d credit%s to do this. You have %d.',
            $required,
            $required === 1 ? '' : 's',
            $balance,
        ));
    }

    /** The shape the app matches on, so it never parses the message text. */
    public function render()
    {
        return response()->json([
            'success'  => false,
            'data'     => null,
            'message'  => $this->getMessage(),
            'code'     => 'insufficient_credits',
            'required' => $this->required,
            'balance'  => $this->balance,
        ], 402);
    }
}
