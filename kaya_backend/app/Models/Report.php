<?php

namespace App\Models;

use App\Support\ModerationReasons;
use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    protected $fillable = [
        'reporter_id', 'reported_id', 'reported_type', 'subject_id',
        'reason', 'reason_code', 'description',
        'status', 'resolution_note', 'resolved_at', 'reviewed_by',
    ];

    protected $casts = [
        'resolved_at' => 'datetime',
    ];

    public function reporter()
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function reported()
    {
        return $this->belongsTo(User::class, 'reported_id');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    /**
     * The reason in words.
     *
     * Reads the catalogue rather than the stored sentence, so rewording an
     * entry updates every report at once. Rows written before `reason_code`
     * existed still have their original free text and fall back to it.
     */
    public function reasonLabel(): string
    {
        return $this->reason_code
            ? ModerationReasons::reportLabel($this->reason_code)
            : ($this->reason ?: 'Not given');
    }

    public function severity(): string
    {
        return ModerationReasons::reportSeverity($this->reason_code);
    }

    /**
     * Orders the queue by how much harm the reason implies, then by age.
     *
     * Strict newest-first buries a threat under a morning of spam reports. The
     * severity is a property of the reason chosen, not a judgement about
     * whether the report is true — a human still decides that.
     */
    public function scopeMostSerious($query)
    {
        $codes = collect(ModerationReasons::REPORT)
            ->map(fn ($r) => ModerationReasons::severityRank($r['severity']));

        // Built as a CASE so the sort happens in the database rather than by
        // loading every pending report into memory to reorder it.
        $case = 'CASE reason_code';
        foreach ($codes as $code => $rank) {
            $case .= " WHEN " . \DB::getPdo()->quote($code) . " THEN {$rank}";
        }
        $case .= ' ELSE 0 END';

        return $query->orderByRaw("{$case} DESC")->orderBy('created_at');
    }
}
