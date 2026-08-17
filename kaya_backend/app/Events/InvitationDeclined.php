<?php

namespace App\Events;

use App\Models\Invitation;
use Illuminate\Foundation\Events\Dispatchable;

class InvitationDeclined
{
    use Dispatchable;

    public function __construct(public Invitation $invitation) {}
}
