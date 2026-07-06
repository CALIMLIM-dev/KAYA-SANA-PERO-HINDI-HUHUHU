<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Skill;
use Illuminate\Database\Seeder;

class SkillSeeder extends Seeder
{
    public function run(): void
    {
        $categorySkills = [
            'Plumbing' => ['Plumbing', 'Pipe Repair', 'Emergency Service', 'Installation', 'Leak Detection'],
            'Electrical' => ['Wiring', 'Circuit Repair', 'Panel Installation', 'Troubleshooting', 'Lighting'],
            'Painting' => ['Interior Painting', 'Exterior Painting', 'Surface Preparation', 'Color Matching'],
            'Carpentry' => ['Cabinet Making', 'Furniture Repair', 'Framing', 'Trim Work', 'Custom Woodwork'],
            'Construction' => ['Concrete Work', 'Masonry', 'Tile Work', 'Drywall', 'Framing'],
            'HVAC' => ['AC Repair', 'Heating Installation', 'Duct Cleaning', 'Maintenance'],
            'Landscaping' => ['Lawn Care', 'Garden Design', 'Tree Trimming', 'Irrigation'],
            'Cleaning' => ['Deep Cleaning', 'Window Cleaning', 'Floor Polishing', 'Sanitization'],
            'Roofing' => ['Roof Repair', 'Installation', 'Inspection', 'Waterproofing'],
            'Flooring' => ['Tile Installation', 'Hardwood', 'Laminate', 'Vinyl'],
            'Automotive' => ['Engine Repair', 'Oil Change', 'Brake Service', 'Diagnostics'],
            'Appliance Repair' => ['Refrigerator', 'Washing Machine', 'Oven', 'Dishwasher'],
            'Security' => ['CCTV Installation', 'Alarm Systems', 'Access Control', 'Monitoring'],
            'Moving' => ['Packing', 'Loading', 'Transportation', 'Unpacking'],
            'Pest Control' => ['Termite Treatment', 'Rodent Control', 'Fumigation', 'Prevention'],
            'Pool Services' => ['Pool Cleaning', 'Chemical Balance', 'Repair', 'Maintenance'],
            'Delivery' => ['Same Day', 'Express', 'Bulk', 'Fragile Items'],
        ];

        foreach ($categorySkills as $categoryName => $skills) {
            $category = Category::where('name', $categoryName)->first();
            
            if ($category) {
                foreach ($skills as $skillName) {
                    Skill::firstOrCreate(
                        ['name' => $skillName, 'category_id' => $category->id]
                    );
                }
            }
        }
    }
}
