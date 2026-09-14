<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

/*
    One line in the audit log. See the migration for why it exists.

    Written through record(), which takes the signed-in admin from the
    session so a controller cannot forget to say who. Append-only: there are
    no updated_at, no fillable route to change a row, and nothing deletes.
*/
class AdminAction extends Model
{
    public $timestamps = false;

    protected $fillable = ['admin_id', 'action', 'subject_type', 'subject_id', 'summary', 'detail', 'created_at'];

    protected $casts = [
        'detail'     => 'array',
        'created_at' => 'datetime',
    ];

    public function admin()
    {
        return $this->belongsTo(User::class, 'admin_id');
    }

    /**
     * @param string      $action   dotted, e.g. 'verification.approved'
     * @param string      $subject  'user' | 'verification' | 'job' | 'report' | 'credit' | 'setting' | 'category' | 'skill' | 'announcement'
     * @param int|null    $id
     * @param string      $summary  one line, in words, for the log page
     * @param array|null  $detail   the specifics, kept for when the line is not enough
     */
    public static function record(string $action, string $subject, ?int $id, string $summary, ?array $detail = null): self
    {
        return static::create([
            'admin_id'     => Auth::id(),
            'action'       => $action,
            'subject_type' => $subject,
            'subject_id'   => $id,
            'summary'      => $summary,
            'detail'       => $detail,
            'created_at'   => now(),
        ]);
    }
}
