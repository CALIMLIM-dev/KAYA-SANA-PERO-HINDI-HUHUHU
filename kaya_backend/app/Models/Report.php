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
        'evidence', 'snapshot', 'response', 'responded_at', 'response_evidence', 'baseless', 'is_automatic',
    ];

    protected $casts = [
        'resolved_at'  => 'datetime',
        'responded_at' => 'datetime',
        'evidence'     => 'array',
        'snapshot'     => 'array',
        'response_evidence' => 'array',
        'baseless'     => 'boolean',
        'is_automatic' => 'boolean',
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


    public function strike()
    {
        return $this->hasOne(Strike::class);
    }

    public function severity(): string
    {
        return ModerationReasons::reportSeverity($this->reason_code);
    }

    /** What was reported: Account, Job Post, Message, Community Post... */
    public function typeLabel(): string
    {
        return ModerationReasons::typeLabel($this->reported_type);
    }

    /*
        How it ended, as the panel's tabs name it. A report confirmed with
        no violation, from before there were three decisions, reads as No
        Violation.
    */
    public const OUTCOMES = [
        'pending'      => 'Pending',
        'violation'    => 'Violation Given',
        'no_violation' => 'No Violation',
        'false'        => 'False Report',
    ];

    public function outcome(): string
    {
        return match (true) {
            in_array($this->status, ['pending', 'reviewed'], true) => 'pending',
            (bool) $this->baseless                                 => 'false',
            $this->strike !== null                                 => 'violation',
            default                                                => 'no_violation',
        };
    }

    public function scopeWithOutcome($query, string $outcome)
    {
        return match ($outcome) {
            'pending'      => $query->whereIn('status', ['pending', 'reviewed']),
            'false'        => $query->where('baseless', true),
            'violation'    => $query->whereNotIn('status', ['pending', 'reviewed'])->whereHas('strike'),
            'no_violation' => $query->whereNotIn('status', ['pending', 'reviewed'])
                ->where(fn ($q) => $q->whereNull('baseless')->orWhere('baseless', false))->whereDoesntHave('strike'),
            default        => $query,
        };
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
