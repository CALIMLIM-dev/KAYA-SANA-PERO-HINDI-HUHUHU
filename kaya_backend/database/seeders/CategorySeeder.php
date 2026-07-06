<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            ['name' => 'Plumbing', 'icon' => 'plumbing', 'is_active' => true],
            ['name' => 'Electrical', 'icon' => 'electrical_services', 'is_active' => true],
            ['name' => 'Painting', 'icon' => 'format_paint', 'is_active' => true],
            ['name' => 'Carpentry', 'icon' => 'carpenter', 'is_active' => true],
            ['name' => 'Construction', 'icon' => 'construction', 'is_active' => true],
            ['name' => 'HVAC', 'icon' => 'ac_unit', 'is_active' => true],
            ['name' => 'Landscaping', 'icon' => 'grass', 'is_active' => true],
            ['name' => 'Cleaning', 'icon' => 'cleaning_services', 'is_active' => true],
            ['name' => 'Roofing', 'icon' => 'roofing', 'is_active' => true],
            ['name' => 'Flooring', 'icon' => 'layers', 'is_active' => true],
            ['name' => 'Automotive', 'icon' => 'car_repair', 'is_active' => true],
            ['name' => 'Appliance Repair', 'icon' => 'kitchen', 'is_active' => true],
            ['name' => 'Security', 'icon' => 'security', 'is_active' => true],
            ['name' => 'Moving', 'icon' => 'local_shipping', 'is_active' => true],
            ['name' => 'Pest Control', 'icon' => 'bug_report', 'is_active' => true],
            ['name' => 'Pool Services', 'icon' => 'pool', 'is_active' => true],
            ['name' => 'Delivery', 'icon' => 'delivery_dining', 'is_active' => true],
        ];

        foreach ($categories as $category) {
            Category::firstOrCreate(
                ['name' => $category['name']],
                $category
            );
        }
    }
}
