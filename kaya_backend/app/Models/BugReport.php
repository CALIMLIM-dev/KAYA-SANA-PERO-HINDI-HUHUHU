<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Something's Broken, from KAYA Assistant. See the migration. */
class BugReport extends Model
{
    public const ISSUES = [
        'app_closed'    => 'The app closed by itself',
        'button'        => 'A button does nothing',
        'wrong_info'    => 'Wrong information is shown',
        'cant_sign_in'  => 'I cannot sign in',
        'something_else' => 'Something else',
    ];

    public const SCREENS = [
        'home' => 'Home', 'jobs' => 'Jobs', 'chat' => 'Chat',
        'wallet' => 'Wallet', 'profile' => 'Profile', 'other' => 'Other',
    ];

    protected $fillable = ['user_id', 'issue', 'screen', 'details', 'screenshot_path', 'app_version', 'device', 'server_error_ids', 'status', 'fixed_at'];

    protected $casts = ['server_error_ids' => 'array', 'fixed_at' => 'datetime'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function issueLabel(): string
    {
        return self::ISSUES[$this->issue] ?? $this->issue;
    }

    public function screenLabel(): string
    {
        return self::SCREENS[$this->screen] ?? $this->screen;
    }
}
