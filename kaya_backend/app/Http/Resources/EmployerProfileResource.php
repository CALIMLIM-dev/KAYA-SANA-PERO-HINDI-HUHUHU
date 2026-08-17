<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class EmployerProfileResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'employer_type' => $this->employer_type?->value,
            'company_name' => $this->company_name,
            'industry' => $this->industry,
            'website' => $this->website,
            'description' => $this->description,
            'location' => $this->location,
            // Structured location. Without these the app can only prefill the
            // display string, which would save a job with no coordinates —
            // the same silent failure the picker now guards against.
            'location_id' => $this->location_id,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'image_path' => $this->image_path,
            'image_url' => $this->image_path ? Storage::disk(config('filesystems.media'))->url($this->image_path) : null,
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
