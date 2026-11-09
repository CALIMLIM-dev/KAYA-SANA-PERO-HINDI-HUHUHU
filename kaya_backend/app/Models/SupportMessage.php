<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One line in an account's conversation with KAYA. */
class SupportMessage extends Model
{
    protected $fillable = ['support_thread_id', 'sender_id', 'from_admin', 'is_assistant', 'assistant_model', 'body', 'read_at'];

    protected $casts = [
        'from_admin' => 'boolean',
        'is_assistant' => 'boolean',
        'read_at'    => 'datetime',
    ];

    public function thread() { return $this->belongsTo(SupportThread::class, 'support_thread_id'); }
    public function sender() { return $this->belongsTo(User::class, 'sender_id'); }

    /** Who wrote an assistant line, for the panel: the model, or why none did. */
    public function assistantSource(): string
    {
        $model = (string) $this->assistant_model;

        return match (true) {
            str_starts_with($model, 'guard') => 'Safety Filter',
            $model === 'limit'               => 'Daily Limit',
            $model === 'none'                => 'No Model Answered',
            $model === 'handoff'             => 'Asked for a Person',
            $model === 'resume'              => 'Back to Assistant',
            $model === 'quick'               => 'Quick Answer',
            $model === ''                    => 'KAYA Assistant',
            default                          => $model,
        };
    }

    /** The name under a line in the panel. */
    public function panelName(?string $personName): string
    {
        return match (true) {
            (bool) $this->is_assistant => 'KAYA Assistant (' . $this->assistantSource() . ')',
            $this->from_admin           => $this->sender?->name ?? 'KAYA',
            default                     => $personName ?? 'Them',
        };
    }
}
