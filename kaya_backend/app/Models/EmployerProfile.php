<?php

namespace App\Models;

use App\Enums\EmployerType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EmployerProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'employer_type',
        'business_structure',
        'tin',
        'company_name',
        'industry',
        'website',
        'description',
        'location',
        'image_path',
        'logo_path', // Kept during migration phase
        'setup_completed',
        // Structured location from the PSGC picker.
        'location_id', 'latitude', 'longitude',
        // Reputation earned as an employer, kept separate from the same
        // person's worker rating — see ReviewController::recomputeRating.
        'rating_avg', 'rating_count',
    ];

    /*
        The TIN never goes to another user.

        It is on every public employer response - the job card's employer,
        the profile a worker opens - and a tax number beside a name is
        enough to impersonate a business. Hidden by default; the owner gets
        it back masked through maskedTin(), and the admin reads it off the
        verification.
    */
    protected $hidden = ['tin'];

    /** The last three digits, for the owner to recognise their own. */
    public function maskedTin(): ?string
    {
        if (blank($this->tin)) {
            return null;
        }

        return str_repeat('*', max(0, strlen($this->tin) - 3)) . substr($this->tin, -3);
    }

    /** Digits only. People type 123-456-789-000 and the dashes are formatting. */
    public static function normaliseTin(?string $raw): ?string
    {
        if ($raw === null) {
            return null;
        }

        $digits = preg_replace('/\D/', '', $raw);

        return $digits === '' ? null : $digits;
    }

    /** The admin who checked the TIN on ORUS. Stamped by the admin panel only. */
    public function tinVerifier()
    {
        return $this->belongsTo(User::class, 'tin_verified_by');
    }

    protected $casts = [
        'employer_type'   => EmployerType::class,
        'setup_completed' => 'boolean',
        'tin_verified_at' => 'datetime',
        // Same casts as WorkerProfile, so a rating serialises identically
        // whichever side of a hire it describes. Without this an employer's
        // rating arrived as 1 where a worker's arrived as "1.00", and the app
        // would render the two differently for no reason a user could explain.
        'rating_avg'      => 'decimal:2',
        'rating_count'    => 'integer',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Determine if employer profile setup is completed.
     *
     * Mirrors WorkerProfile::isSetupCompleted() — derived from the data itself
     * rather than the setup_completed column, so it stays correct if the user
     * later edits their profile and clears a required field.
     *
     * A company needs a company name; an individual is identified by the name
     * on their user account.
     */
    public function isSetupCompleted(): bool
    {
        if (is_null($this->employer_type) || !filled($this->location)) {
            return false;
        }

        return $this->employer_type === EmployerType::COMPANY
            ? filled($this->company_name)
            : filled($this->user?->name);
    }
}

