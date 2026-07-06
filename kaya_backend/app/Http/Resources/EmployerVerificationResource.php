<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EmployerVerificationResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'identity_verified' => $this->resource['identity_verified'],
            'identity_status' => $this->resource['identity_status'] ?? 'unverified',
            'business_verified' => $this->resource['business_verified'],
            'business_status' => $this->resource['business_status'] ?? 'unverified',
            'requires_business_verification' => $this->resource['requires_business_verification'],
            'fully_verified' => $this->resource['fully_verified'],
        ];
    }
}
