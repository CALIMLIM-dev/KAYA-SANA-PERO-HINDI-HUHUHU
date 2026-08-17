<?php

namespace App\Events;

use App\Models\Invitation;
use Illuminate\Foundation\Events\Dispatchable;

class InvitationAccepted
{
    use Dispatchable;

    public function __construct(public Invitation $invitation) {}
}
