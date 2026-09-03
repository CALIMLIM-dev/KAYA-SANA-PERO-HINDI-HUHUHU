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

    protected $casts = [
        'employer_type'   => EmployerType::class,
        'setup_completed' => 'boolean',
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

