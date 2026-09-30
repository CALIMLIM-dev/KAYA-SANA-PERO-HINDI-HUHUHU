<?php

namespace App\Services;

use App\Enums\EmployerType;
use App\Models\User;
use App\Models\EmployerProfile;
use App\Models\Verification;

class EmployerVerificationService
{
    /*
        What each kind of employer has to prove.

        An individual is a person, so they prove who they are: a
        government ID, the same one the worker side asks for.

        A company is not a person. What is being vouched for is the
        business - its registration and its TIN - and the ID of
        whoever happens to be holding the phone proves nothing about
        it. That person is staff; they may leave next month, and the
        business is still the business. So a company is verified by
        its papers and is not asked for anybody's ID.

        This used to require both of a company, which is why a company
        profile showed a Valid ID card and a screen headed Government
        ID Verification.
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

        /*
            A company's papers are the whole of it.

            The identity fields are still reported, because the admin
            panel shows what was submitted either way and an older
            company account may have an approved ID on file - it just
            no longer decides anything.
        */
        $fullyVerified = $requiresBusinessVerification
            ? $businessVerified
            : $identityVerified;

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
