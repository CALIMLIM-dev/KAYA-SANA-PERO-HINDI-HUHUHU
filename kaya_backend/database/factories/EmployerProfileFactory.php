<?php

namespace Database\Factories;

use App\Enums\EmployerType;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\EmployerProfile>
 */
class EmployerProfileFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'employer_type' => EmployerType::COMPANY,
            'company_name' => fake()->company(),
            'industry' => fake()->randomElement(['Technology', 'Construction', 'Healthcare', 'Education', 'Retail']),
            'website' => fake()->url(),
            'description' => fake()->paragraph(),
            'location' => fake()->city(),
        ];
    }

    /**
     * Indicate that the employer is a company.
     */
    public function company(): static
    {
        return $this->state(fn (array $attributes) => [
            'employer_type' => EmployerType::COMPANY,
            'company_name' => fake()->company(),
            'industry' => fake()->randomElement(['Technology', 'Construction', 'Healthcare']),
        ]);
    }

    /**
     * Indicate that the employer is an individual.
     */
    public function individual(): static
    {
        return $this->state(fn (array $attributes) => [
            'employer_type' => EmployerType::INDIVIDUAL,
            'company_name' => null,
            'industry' => null,
            'website' => null,
        ]);
    }
}
