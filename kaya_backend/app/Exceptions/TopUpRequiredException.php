<?php

namespace App\Exceptions;

/*
    Something only an account that has topped up can do.

    Free gets the marketplace; a top-up of any size gets promotion - boosting,
    a post that runs past the free week, more than one board post. See the
    Free vs Top-up checklist on the wallet screen, which is this rule drawn.

    A kind of InsufficientCreditsException on purpose. Every place that
    already catches that one - the job post, the edit, the urgent boost that
    quietly falls back to an unboosted post - handles this the same way
    without being touched, and a new door that forgets to catch it still gets
    a clear refusal rather than a 500.
*/
class TopUpRequiredException extends InsufficientCreditsException
{
    public function __construct(string $message)
    {
        \Exception::__construct($message);
    }

    public function render()
    {
        return response()->json([
            'success' => false,
            'data'    => null,
            'message' => $this->getMessage(),
            'code'    => 'top_up_required',
        ], 422);
    }
}
