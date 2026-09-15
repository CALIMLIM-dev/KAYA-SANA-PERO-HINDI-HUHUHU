<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\SkillAssessment;
use Illuminate\Database\Seeder;

/*
    A starter bank of skill checks, one per common trade.

    Basics and safety, the things anyone who does the work knows and
    anyone who does not will guess at. The administrator edits, replaces
    and adds from the Skill Checks page; this only makes sure a fresh
    install has something to offer on day one. Runs once: a trade that
    already has a test is left alone.
*/
class AssessmentSeeder extends Seeder
{
    public function run(): void
    {
        foreach ($this->bank() as $categoryName => $questions) {
            $category = Category::where('name', $categoryName)->first();

            if (! $category || SkillAssessment::where('category_id', $category->id)->exists()) {
                continue;
            }

            $assessment = SkillAssessment::create([
                'category_id' => $category->id,
                'title'       => "{$categoryName} skill check",
                'pass_mark'   => 70,
                'is_active'   => true,
            ]);

            foreach ($questions as $i => [$prompt, $choices, $answer]) {
                $assessment->questions()->create([
                    'prompt'       => $prompt,
                    'choices'      => $choices,
                    'answer_index' => $answer,
                    'sort_order'   => $i + 1,
                ]);
            }
        }
    }

    /** category => [[prompt, [four choices], index of the right one], ...] */
    private function bank(): array
    {
        return [
            'Electrical' => [
                ['Before working on a circuit, what do you do first?',
                    ['Turn off the breaker and confirm the line is dead with a tester', 'Wear rubber slippers', 'Work quickly so the power is off for less time', 'Cover the wire with tape'], 0],
                ['What is the normal household voltage in the Philippines?',
                    ['110 volts', '220 volts', '380 volts', '12 volts'], 1],
                ['A breaker keeps tripping after you reset it. What does that most likely mean?',
                    ['The breaker is defective and should be bypassed', 'There is an overload or a short on that circuit', 'The meter is running fast', 'Nothing, breakers trip at random'], 1],
                ['What is the purpose of a ground wire?',
                    ['To carry the normal current back to the panel', 'To give fault current a safe path so the breaker trips', 'To reduce the electric bill', 'To make the outlet fit the plug'], 1],
                ['Which wire size is thicker?',
                    ['3.5 square millimetres', '2.0 square millimetres', '1.25 square millimetres', 'They are all the same'], 0],
                ['Where should electrical splices be made?',
                    ['Anywhere along the wire as long as they are taped', 'Inside a junction box', 'Behind the ceiling board where nobody sees them', 'Inside the conduit'], 1],
                ['An appliance cord is warm to the touch while in use. What should you check?',
                    ['Whether the cord is undersized or damaged for the load', 'Nothing, warm cords are normal', 'Whether the wall paint is dry', 'Whether the appliance is new'], 0],
                ['What does a GFCI or residual current device protect against?',
                    ['Lightning', 'Electric shock from current leaking to ground', 'High electric bills', 'Voltage drop'], 1],
            ],
            'Plumbing' => [
                ['Before cutting into a water line, what do you do first?',
                    ['Shut off the supply and open a tap to drain it', 'Put a bucket under it', 'Wrap the pipe with a rag', 'Cut fast so less water escapes'], 0],
                ['What is Teflon tape for?',
                    ['Sealing threaded joints', 'Gluing PVC pipe', 'Holding a pipe to the wall', 'Insulating hot water pipes'], 0],
                ['Which pipe is used for cold water supply in most Philippine homes?',
                    ['PVC blue pipe', 'Orange PVC sanitary pipe', 'Galvanised gas pipe', 'Rubber hose'], 0],
                ['A P-trap under a sink is there to',
                    ['Increase water pressure', 'Hold water so sewer gas cannot come up the drain', 'Filter dirt from the water', 'Make the drain quieter'], 1],
                ['PVC cement joints should be',
                    ['Primed, cemented, pushed together with a quarter turn and held', 'Cemented and pulled apart to check', 'Left loose until the water is on', 'Tightened with a wrench'], 0],
                ['A faucet drips from the spout when closed. The most common cause is',
                    ['A worn washer or cartridge', 'Low water pressure', 'Air in the line', 'A blocked drain'], 0],
                ['Which way does a sanitary drain line need to slope?',
                    ['Downhill toward the outlet', 'Uphill toward the fixture', 'Perfectly level', 'It does not matter'], 0],
                ['Which tool cuts PVC pipe cleanly?',
                    ['A PVC cutter or a fine-toothed hacksaw', 'An angle grinder', 'A hammer and chisel', 'Pliers'], 0],
            ],
            'Carpentry' => [
                ['Which is the safest way to use a circular saw?',
                    ['Clamp the work, keep both hands on the saw, and keep the guard in place', 'Hold the board with one hand and cut with the other', 'Remove the guard so you can see the blade', 'Cut toward yourself'], 0],
                ['A 2x4 nominal lumber is actually about',
                    ['2 by 4 inches', '1.5 by 3.5 inches', '3 by 5 inches', '2 by 3 inches'], 1],
                ['To check that a corner is square, you can use',
                    ['A 3-4-5 triangle', 'A plumb bob', 'A spirit level', 'A tape measure only'], 0],
                ['Marine plywood is used where',
                    ['The wood will get wet or humid', 'The wood must be cheap', 'The surface needs to be painted', 'Weight must be kept low'], 0],
                ['When driving a screw near the end of a board, you should',
                    ['Drill a pilot hole first so the wood does not split', 'Use a bigger screw', 'Hammer it in', 'Skip the screw'], 0],
                ['What does a spirit level check?',
                    ['Whether a surface is level or plumb', 'Whether a corner is square', 'The moisture in the wood', 'The length of a board'], 0],
                ['Termite-damaged framing should be',
                    ['Painted over', 'Replaced and the source treated', 'Covered with plywood', 'Left if it still looks straight'], 1],
                ['Measure twice, cut once means',
                    ['Cut every board twice', 'Check the measurement before cutting because a cut cannot be undone', 'Measure in two units', 'Always cut with two people'], 1],
            ],
            'Painting' => [
                ['Before painting a wall, the surface should be',
                    ['Clean, dry, and sanded smooth with holes filled', 'Wet so the paint spreads', 'Painted immediately over dirt', 'Covered in oil'], 0],
                ['What is primer for?',
                    ['To make paint stick and cover evenly', 'To make paint dry slower', 'To add gloss', 'To thin the paint'], 0],
                ['For exterior concrete walls, the usual paint is',
                    ['Elastomeric or acrylic latex', 'Enamel oil paint', 'Chalk', 'Wood stain'], 0],
                ['Paint is streaking and showing brush marks. What helps most?',
                    ['Thin lighter coats with the right roller or brush', 'One thick coat', 'Painting in direct hot sun', 'Adding water until it drips'], 0],
                ['Enamel paint brushes are cleaned with',
                    ['Water', 'Paint thinner', 'Soap only', 'Sandpaper'], 1],
                ['Masking tape should be removed',
                    ['While the paint is still slightly wet or just dry, pulled at an angle', 'After a week', 'Never', 'Before painting'], 0],
                ['Painting a ceiling, you work',
                    ['Ceiling first, then walls, then trim', 'Trim first, then ceiling', 'Walls first, then ceiling', 'In any order'], 0],
                ['Mildew stains on a bathroom wall should be',
                    ['Painted over directly', 'Cleaned with a bleach solution and dried before painting', 'Sanded only', 'Covered with wallpaper'], 1],
            ],
            'Construction' => [
                ['On site, a hard hat is worn',
                    ['Whenever there is work overhead or falling objects are possible', 'Only when the foreman is watching', 'Only on rainy days', 'Never, it is too hot'], 0],
                ['The usual mix ratio for general concrete, cement to sand to gravel, is about',
                    ['1 : 2 : 4', '4 : 2 : 1', '1 : 1 : 1', '1 : 10 : 10'], 0],
                ['Rebar in a concrete beam is there to',
                    ['Take the tension concrete cannot', 'Make the beam lighter', 'Speed up curing', 'Hold the formwork'], 0],
                ['Freshly poured concrete should be',
                    ['Kept moist and allowed to cure for days', 'Left to dry as fast as possible in the sun', 'Loaded immediately', 'Painted the same day'], 0],
                ['A hollow block wall is laid',
                    ['With staggered joints, checked plumb and level each course', 'With joints stacked straight above each other', 'Without mortar', 'From the top down'], 0],
                ['Working from a ladder, you should',
                    ['Keep three points of contact and not overreach', 'Stand on the top rung', 'Lean the ladder on a loose surface', 'Carry heavy loads while climbing'], 0],
                ['Formwork is removed',
                    ['Once the concrete has gained enough strength, per the schedule', 'The moment the surface looks dry', 'Before the pour finishes', 'After a year'], 0],
                ['Digging a trench deeper than about a metre and a half, the walls should be',
                    ['Shored or sloped to prevent collapse', 'Left vertical to save space', 'Watered', 'Ignored'], 0],
            ],
            'Cleaning' => [
                ['Bleach and ammonia cleaners should',
                    ['Never be mixed', 'Be mixed for extra strength', 'Be mixed only outdoors', 'Be mixed for tiles only'], 0],
                ['To avoid spreading dirt, you clean a room',
                    ['Top to bottom, dry before wet', 'Floor first, then ceiling', 'Wet everything first', 'In any order'], 0],
                ['Cloths used in the toilet should',
                    ['Be kept separate from kitchen cloths', 'Be reused in the kitchen once rinsed', 'Be used everywhere', 'Be dried on the counter'], 0],
                ['A wet floor in a shared area should',
                    ['Have a sign or be blocked off until dry', 'Be left, it dries quickly', 'Be covered with a rug', 'Be fanned only'], 0],
                ['Gloves are worn when',
                    ['Handling chemicals and bathroom cleaning', 'Only when dusting', 'Never', 'Only in winter'], 0],
                ['Glass is cleaned streak-free by',
                    ['Wiping with a squeegee or a clean microfibre cloth', 'Using a wet sponge only', 'Using a scouring pad', 'Rubbing with newspaper and oil'], 0],
                ['Wooden furniture is cleaned with',
                    ['A damp cloth and a mild cleaner, then dried', 'Soaking water', 'Bleach', 'A wire brush'], 0],
                ['Waste from a client should be',
                    ['Sorted and disposed of as they instruct', 'Left in the corner', 'Taken home', 'Burned'], 0],
            ],
            'Appliance Repair' => [
                ['Before opening any appliance, you',
                    ['Unplug it from the wall', 'Turn the knob to off', 'Put a towel over it', 'Ask the client to hold the plug'], 0],
                ['A capacitor in a washing machine or air conditioner can',
                    ['Hold a charge after the power is off and must be discharged', 'Be handled freely once unplugged', 'Be tested by touching the terminals', 'Not store any charge'], 0],
                ['A refrigerator that runs but does not cool most likely has',
                    ['A refrigerant, compressor or airflow problem', 'A broken door handle', 'A loose plug', 'The wrong colour'], 0],
                ['A multimeter set to continuity is used to check',
                    ['Whether a fuse, switch or heating element is open', 'The water level', 'The temperature', 'The weight'], 0],
                ['An electric fan that hums but does not spin usually needs',
                    ['The bearings oiled or the capacitor replaced', 'A new plug', 'More voltage', 'A bigger blade'], 0],
                ['Replacement parts should',
                    ['Match the rating on the original part or the label', 'Be whatever fits', 'Be the cheapest available', 'Be bigger to last longer'], 0],
                ['After a repair, you',
                    ['Test the appliance in front of the client', 'Leave before it is switched on', 'Ask the client to test it later', 'Test only if asked'], 0],
                ['A gas stove smells of gas with the burners off. You',
                    ['Close the tank valve, ventilate, and check for leaks with soapy water', 'Light a burner to burn it off', 'Ignore it', 'Spray perfume'], 0],
            ],
            'HVAC' => [
                ['Before servicing an air conditioner you',
                    ['Switch off the breaker for the unit', 'Turn the thermostat down', 'Remove the filter only', 'Spray the coils while it runs'], 0],
                ['A dirty air filter causes',
                    ['Weak airflow and poor cooling', 'Better cooling', 'Lower electric bills', 'Nothing'], 0],
                ['Refrigerant is',
                    ['Handled and recovered properly, never released into the air', 'Released outside when the unit is emptied', 'Poured down a drain', 'Stored in a soft drink bottle'], 0],
                ['Ice forming on the evaporator coil can mean',
                    ['Low refrigerant or poor airflow', 'The unit is too powerful', 'The room is too cold', 'The filter is new'], 0],
                ['The condensate drain line should',
                    ['Slope away and be kept clear so water does not back up', 'Be plugged', 'Run uphill', 'Be connected to the power line'], 0],
                ['Split-type units are sized by',
                    ['Horsepower or cooling capacity matched to the room size', 'Colour', 'Brand only', 'Weight'], 0],
                ['When cleaning coils, you use',
                    ['A soft brush, a coil cleaner and low pressure water', 'A wire brush', 'A high pressure jet at close range', 'Sandpaper'], 0],
                ['A unit that trips the breaker on start may have',
                    ['A failing compressor or capacitor', 'A dirty remote', 'Too much refrigerant colour', 'A loose filter'], 0],
            ],
        ];
    }
}
