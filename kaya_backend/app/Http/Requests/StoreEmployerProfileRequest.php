<?php

namespace App\Http\Requests;

use App\Enums\EmployerType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Enum;

class StoreEmployerProfileRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        $rules = [
            'employer_type' => ['required', 'in:company,individual'],
        ];

        // Dynamic validation based on employer type
        $employerType = $this->input('employer_type');

        if ($employerType === 'company') {
            $rules['company_name'] = ['required', 'string', 'max:255'];
            $rules['industry'] = ['required', 'string', 'max:255'];
            $rules['location'] = ['required', 'string', 'max:255'];
            $rules['location_id'] = ['nullable', 'exists:locations,id'];
            $rules['latitude'] = ['nullable', 'numeric', 'between:-90,90'];
            $rules['longitude'] = ['nullable', 'numeric', 'between:-180,180'];
            $rules['website'] = ['nullable', 'url', 'max:255'];
            $rules['description'] = ['nullable', 'string', 'max:2000'];
        } elseif ($employerType === 'individual') {
            $rules['location'] = ['required', 'string', 'max:255'];
            $rules['location_id'] = ['nullable', 'exists:locations,id'];
            $rules['latitude'] = ['nullable', 'numeric', 'between:-90,90'];
            $rules['longitude'] = ['nullable', 'numeric', 'between:-180,180'];
            $rules['description'] = ['nullable', 'string', 'max:2000'];
        }

        return $rules;
    }

    /**
     * Get custom messages for validator errors.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'employer_type.required' => 'Please select whether you are registering as a company or individual.',
            'company_name.required' => 'Company name is required for company employers.',
            'industry.required' => 'Industry is required for company employers.',
            'location.required' => 'Location is required.',
        ];
    }
}
