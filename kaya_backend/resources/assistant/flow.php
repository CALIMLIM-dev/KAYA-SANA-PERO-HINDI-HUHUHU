<?php

/*
    KAYA Assistant's guided menu: topics, the issues under each, and what the
    assistant says and offers for each one. No model is asked for any of it.

    answer:  the written answer, from the same checked help as knowledge.md.
    read:    the person's own records to read first (SupportFlow::read):
             standing, wallet, verification, hires, applications.
    actions: screens the app opens from buttons on the answer
             (SupportFlow::ACTIONS).

    The "bug" topic is special: the app opens its report form.
*/
return [
    'account' => [
        'label'  => 'Account or Suspension',
        'issues' => [
            'suspended' => [
                'label'   => 'Why is my account suspended?',
                'read'    => 'standing',
                'answer'  => 'Account Status shows each violation, what it means and when a suspension ends.',
                'actions' => ['account_status'],
            ],
            'appeal' => [
                'label'   => 'How do I appeal?',
                'read'    => 'standing',
                'answer'  => "1. Open Account Status.\n2. Choose the violation and tap Appeal.\n3. Write your reason and send it.\nYou can appeal within 30 days of the violation. A KAYA admin reviews it and you are told the outcome.",
                'actions' => ['account_status'],
            ],
            'profiles' => [
                'label'   => 'Worker and employer profiles',
                'answer'  => 'One account can hold both a worker and an employer profile. Switch with the Worker and Employer buttons on the home screen. A registered business cannot also have a worker profile.',
                'actions' => ['profile'],
            ],
            'delete' => [
                'label'   => 'Delete my account',
                'answer'  => 'Profile, Settings, then the last row. It asks for your password and cannot be undone. It is refused while you are on a job in progress.',
                'actions' => ['profile'],
            ],
        ],
    ],
    'barya' => [
        'label'  => 'Barya and Top-up',
        'issues' => [
            'topup_missing' => [
                'label'   => 'My top-up did not arrive',
                'read'    => 'wallet',
                'answer'  => 'While KAYA is in testing, top-ups are added at once. If it is not in your history, it did not go through. Try again from My Wallet.',
                'actions' => ['wallet_history', 'wallet'],
            ],
            'refund' => [
                'label'   => 'I did not get my Barya back',
                'read'    => 'wallet',
                'answer'  => 'Barya comes back on its own when you withdraw within an hour of applying, or when a job is deleted or its post ends while you are still waiting. The Refund Policy at the bottom of My Wallet lists every case.',
                'actions' => ['wallet_history'],
            ],
            'free' => [
                'label'   => 'Free Barya',
                'read'    => 'wallet',
                'answer'  => 'Claim free Barya in My Wallet when you start and again each month. Badges earn some too.',
                'actions' => ['wallet'],
            ],
            'how_topup' => [
                'label'   => 'How do I top up?',
                'answer'  => "1. Open Profile, then My Wallet.\n2. Choose a package.\nWhile KAYA is in testing, top-ups are free and added at once. You need a verified account.",
                'actions' => ['wallet'],
            ],
        ],
    ],
    'job' => [
        'label'  => 'Job Problem',
        'issues' => [
            'finish' => [
                'label'   => 'How do I finish a job?',
                'read'    => 'hires',
                'answer'  => 'When the work is done, you and the other person each tap Mark as Complete. It is complete once both have.',
                'actions' => ['active'],
            ],
            'no_show' => [
                'label'   => 'They did not show up',
                'read'    => 'hires',
                'answer'  => 'Open the hire and use Cancel Job, or Report a Problem if they marked it complete. KAYA reviews every report.',
                'actions' => ['active'],
            ],
            'not_paid' => [
                'label'   => 'I was not paid',
                'read'    => 'hires',
                'answer'  => 'KAYA does not hold job payments; pay is agreed and paid between the two of you. Open the hire and tap Report a Problem, then choose Not paid. A KAYA admin reviews it.',
                'actions' => ['active'],
            ],
            'applications' => [
                'label'   => 'My applications',
                'read'    => 'applications',
                'answer'  => 'Every job you applied to or were invited to is in My Applications.',
                'actions' => ['applications'],
            ],
        ],
    ],
    'verification' => [
        'label'  => 'Verification',
        'issues' => [
            'status' => [
                'label'   => 'Where is my verification?',
                'read'    => 'verification',
                'answer'  => 'An admin reviews the documents and you get a notification either way.',
                'actions' => ['profile'],
            ],
            'refused' => [
                'label'   => 'My verification was refused',
                'read'    => 'verification',
                'answer'  => 'Open your profile, go to Verification and upload the documents again with every corner in the photo and the text easy to read.',
                'actions' => ['profile'],
            ],
            'how' => [
                'label'   => 'How do I get verified?',
                'answer'  => "1. Open the Profile tab, then your worker or employer profile.\n2. Tap Verification.\n3. Upload a Philippine government ID and a selfie holding it. A business uploads its DTI certificate, SEC registration or Mayor's permit.",
                'actions' => ['profile'],
            ],
        ],
    ],
    'bug' => [
        'label'  => "Something's Broken",
        'issues' => [],
    ],
];
