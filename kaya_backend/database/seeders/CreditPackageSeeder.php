<?php

namespace Database\Seeders;

use App\Models\CreditPackage;
use Illuminate\Database\Seeder;

/*
    What a top-up costs, priced for the Philippines rather than copied from a
    marketplace that bills in dollars.

    The anchor is prepaid load. Filipinos buy airtime in 20, 50 and 100 peso
    steps, from a sari-sari store or through GCash, and that is the shape money
    leaves a phone in. A marketplace whose smallest option is 500 pesos is not
    expensive so much as unfamiliar, and unfamiliar is worse: people do not
    haggle with it, they just never buy.

    So the ladder starts at 50 pesos and the credit gets cheaper as the bundle
    grows. The discount is real, not decorative — 1.43 pesos a credit at the
    top against 2.00 at the bottom, a 29 percent difference — because the whole
    job of a ladder is to make the next rung worth stepping on.

    Sized against the work, not against a wage. A day of local service work is
    roughly 400 to 650 pesos here. At two credits an application, the 50 peso
    tier buys twelve applications for less than a tenth of one day's pay, and
    the 100 peso tier buys thirty. Nobody sensible refuses that trade for work
    they actually want, which is the only test a fee has to pass.

    One number to confirm before this goes live: the provider's minimum
    chargeable amount. If it will not accept 50 pesos on the method most people
    here use, the bottom rung moves up to 100 and the ladder still works — but
    that must be checked against the provider rather than assumed, because
    getting it wrong means the cheapest option fails at the moment of payment,
    for exactly the people least able to pick a dearer one.
*/
class CreditPackageSeeder extends Seeder
{
    public function run(): void
    {
        $packages = [
            [
                'name' => 'Load',
                'credits' => 25,
                'amount_centavos' => 5000,      // 50.00 -> 2.00 a credit
                'sort_order' => 1,
            ],
            [
                'name' => 'Regular',
                'credits' => 60,
                'amount_centavos' => 10000,     // 100.00 -> 1.67 a credit
                'sort_order' => 2,
            ],
            [
                'name' => 'Sulit',
                'credits' => 175,
                'amount_centavos' => 25000,     // 250.00 -> 1.43 a credit
                'sort_order' => 3,
            ],
            [
                'name' => 'Negosyo',
                'credits' => 400,
                'amount_centavos' => 50000,     // 500.00 -> 1.25 a credit
                'sort_order' => 4,
            ],

            /*
                Business tiers, shown only to a verified company.

                The individual curve runs 2.00 down to 1.25 a credit; these
                continue it to 1.00, 0.90 and 0.80. A business posting
                steadily and boosting spends at a rate that would mean buying
                the 400 bundle over and over, which is a worse deal for them
                and more PayMongo fees for us.
            */
            [
                'name' => 'Business Starter',
                'credits' => 600,
                'amount_centavos' => 60000,     // 600.00 -> 1.00 a credit
                'audience' => 'business',
                'sort_order' => 5,
            ],
            [
                'name' => 'Business Growth',
                'credits' => 1500,
                'amount_centavos' => 135000,    // 1,350.00 -> 0.90 a credit
                'audience' => 'business',
                'sort_order' => 6,
            ],
            [
                'name' => 'Business Scale',
                'credits' => 3500,
                'amount_centavos' => 280000,    // 2,800.00 -> 0.80 a credit
                'audience' => 'business',
                'sort_order' => 7,
            ],
        ];

        foreach ($packages as $package) {
            // Keyed on the name so re-seeding corrects a price rather than
            // adding a second row people could still buy from.
            CreditPackage::updateOrCreate(
                ['name' => $package['name']],
                $package + ['is_active' => true],
            );
        }
    }
}
