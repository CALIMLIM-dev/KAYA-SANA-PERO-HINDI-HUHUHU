<?php

namespace App\Services;

use App\Enums\EmployerType;
use App\Models\User;
use App\Models\EmployerProfile;
use App\Models\Verification;

class EmployerVerificationService
{
    /**
     * Get employer verification status
     * 
     * Verification Hierarchy:
     * - Account-level: Government ID (shared by worker + individual employer)
     * - Profile-level: Business Registration (company employers only)
     * 
     * @param User $user
     * @param EmployerProfile|null $profile
     * @return array
     */
    public function getEmployerVerification(User $user, ?EmployerProfile $profile): array
    {
        // Fetch all relevant verifications in a SINGLE query
        $verifications = $user->verifications()
            ->whereIn('document_type', ['government_id', 'business_reg'])
            ->latest('created_at')
            ->latest('id')
            ->get()
            ->unique('document_type')
            ->keyBy('document_type');

        // Get account-level government ID verification
        $identityVerification = $verifications->get('government_id');
        $identityStatus = $identityVerification?->status ?? 'unverified';
        $identityVerified = $identityStatus === 'verified';

        // Business registration only applies to company employers
        $businessVerified = false;
        $businessStatus = 'unverified';
        $requiresBusinessVerification = false;

        if ($profile && $profile->employer_type) {
            $requiresBusinessVerification = $profile->employer_type->requiresBusinessVerification();

            if ($requiresBusinessVerification) {
                $businessVerification = $verifications->get('business_reg');
                $businessStatus = $businessVerification?->status ?? 'unverified';
                $businessVerified = $businessStatus === 'verified';
            }
        }

        // Determine overall verification status
        $fullyVerified = $identityVerified && (!$requiresBusinessVerification || $businessVerified);

        return [
            'identity_verified' => $identityVerified,
            'identity_status' => $identityStatus,
            'business_verified' => $businessVerified,
            'business_status' => $businessStatus,
            'requires_business_verification' => $requiresBusinessVerification,
            'fully_verified' => $fullyVerified,
        ];
    }

    /**
     * Check if employer type requires business verification
     * 
     * @param EmployerType $type
     * @return bool
     */
    public function requiresBusinessVerification(EmployerType $type): bool
    {
        return $type->requiresBusinessVerification();
    }
}
