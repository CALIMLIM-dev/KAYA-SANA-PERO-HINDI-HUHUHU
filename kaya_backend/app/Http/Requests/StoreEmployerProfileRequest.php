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
    /*
        Digits only, before anything is checked.

        A TIN is printed as 123-456-789-000 and that is how people type
        it. Refusing the punctuation would be refusing the number as it
        appears on the certificate being uploaded beside it.
    */
    protected function prepareForValidation(): void
    {
        if ($this->filled('tin')) {
            $this->merge(['tin' => preg_replace('/\D/', '', (string) $this->input('tin'))]);
        }
    }

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
            /*
                The TIN, asked for here rather than buried in an upload.

                It is part of what identifies a business, so it belongs
                with the business details. It used to appear only on the
                Business Registration upload screen, under the document
                picker, and only when a provider happened to already be
                loaded - so most companies never saw the field, no TIN
                was ever stored, and the ORUS check the admin panel
                refuses to approve without was skipped every time for
                want of a number.

                Nine digits, or twelve with the branch code.
                prepareForValidation strips the punctuation first, so a
                number typed the way it is printed still passes.
            */
            $rules['tin'] = ['required', 'string', 'regex:/^\d{9}(\d{3})?$/'];
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
            'tin.required' => 'Your business TIN is required.',
            'tin.regex' => 'A TIN is 9 digits, or 12 with the branch code.',
        ];
    }
}
