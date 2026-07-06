<?php

namespace App\Enums;

enum EmployerType: string
{
    case COMPANY = 'company';
    case INDIVIDUAL = 'individual';

    /**
     * Get human-readable label
     */
    public function label(): string
    {
        return match($this) {
            self::COMPANY => 'Company',
            self::INDIVIDUAL => 'Individual',
        };
    }

    /**
     * Check if this employer type requires business registration verification
     */
    public function requiresBusinessVerification(): bool
    {
        return match($this) {
            self::COMPANY => true,
            self::INDIVIDUAL => false,
        };
    }

    /**
     * Get required fields for this employer type
     */
    public function requiredFields(): array
    {
        return match($this) {
            self::COMPANY => [
                'company_name',
                'industry',
                'location',
            ],
            self::INDIVIDUAL => [
                'location',
            ],
        };
    }

    /**
     * Get optional fields for this employer type
     */
    public function optionalFields(): array
    {
        return match($this) {
            self::COMPANY => [
                'description',
                'website',
            ],
            self::INDIVIDUAL => [
                'description',
            ],
        };
    }

    /**
     * Get all valid fields for this employer type
     */
    public function validFields(): array
    {
        return array_merge($this->requiredFields(), $this->optionalFields());
    }
}
