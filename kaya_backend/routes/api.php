<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\WorkerProfileController;
use App\Http\Controllers\Api\V1\EmployerProfileController;
use App\Http\Controllers\Api\V1\JobController;
use App\Http\Controllers\Api\V1\ApplicationController;
use App\Http\Controllers\Api\V1\InvitationController;
use App\Http\Controllers\Api\V1\JobTrackingController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\ProfileViewController;
use App\Http\Controllers\Api\V1\RealtimeController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\CreditCheckoutController;
use App\Http\Controllers\Api\V1\CreditController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\ReviewController;
use App\Http\Controllers\Api\V1\SkillController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\LocationController;
use App\Http\Controllers\Api\V1\ContactVerificationController;
use App\Http\Controllers\Api\V1\VerificationController;
use App\Http\Controllers\Api\V1\VerificationDocumentController;

Route::prefix('v1')->group(function () {

    /*
        PayMongo tells us a payment succeeded. Public, because it is called by
        PayMongo rather than by anyone signed in — the signature is what
        authenticates it, checked against the raw body.

        Its own rate limit, well above normal traffic. The global API limit
        would throttle PayMongo's retries during a burst, and a throttled
        retry looks exactly like a provider outage while quietly costing
        somebody the credits they paid for.
    */
    Route::post('/webhooks/paymongo', [CreditCheckoutController::class, 'webhook'])
        ->middleware('throttle:paymongo-webhook');

    // ── Auth (public) ─────────────────────────────────────────────────────────
    // Throttled per IP. Credential-guessing endpoints get the tighter limit;
    // verify-reset-code especially, since the code is only 6 digits and is valid
    // for 15 minutes (~1e6 space, trivially brute-forceable unthrottled).
    Route::middleware('throttle:auth')->group(function () {
        Route::post('/login',        [AuthController::class, 'login']);
        Route::post('/google-login', [AuthController::class, 'googleLogin']);
    });

    Route::middleware('throttle:auth')->group(function () {
        Route::post('/register',          [AuthController::class, 'register']);
        Route::post('/forgot-password',   [AuthController::class, 'forgotPassword']);
        Route::post('/verify-reset-code', [AuthController::class, 'verifyResetCode']);
        Route::post('/reset-password',    [AuthController::class, 'resetPassword']);
    });

    // ── Authenticated ─────────────────────────────────────────────────────────
    // not.suspended: a ban has to hold on every endpoint, not on the three that
    // happened to check it. /me and /logout stay reachable so a suspended user
    // can read why, and sign out.
    Route::middleware(['auth:sanctum', 'not.suspended'])->group(function () {

        // Where the WebSocket server lives. Fetched once after login so the
        // host isn't compiled into the app binary.
        Route::get('/realtime/config', [RealtimeController::class, 'config']);

        /*
            Signing out must work even when the token is already gone.
            Suspension DELETES a user's tokens, so a banned client could never
            reach this endpoint - it 401'd, the sign-out never completed, and
            the phone sat in a 401 loop polling forever. Logging out with no
            valid token is a no-op, not an error.
        */
        Route::post('/logout', [AuthController::class, 'logout'])
            ->withoutMiddleware(['auth:sanctum', 'not.suspended']);
        Route::get('/me',      [AuthController::class, 'me']);
        Route::get('/check-status', [AuthController::class, 'checkStatus']);
        Route::patch('/me',    [AuthController::class, 'updateMe']);

        // Settings. Password changes are throttled because the endpoint takes
        // the current password and so can be used to test guesses.
        Route::put('/me/password', [AuthController::class, 'changePassword'])
            ->middleware('throttle:auth');
        Route::get('/me/notification-preferences',  [AuthController::class, 'notificationPreferences']);
        Route::put('/me/notification-preferences',  [AuthController::class, 'updateNotificationPreferences']);
        Route::get('/user',    [AuthController::class, 'user']);

        // Locations (PSGC lookup for the location picker)
        Route::get('/locations/search',  [LocationController::class, 'search']);
        Route::get('/locations/nearest', [LocationController::class, 'nearest']);
        Route::get('/locations/{location}', [LocationController::class, 'show']);

        // Worker directory (employer-mode browse/search)
        Route::get('/workers', [WorkerProfileController::class, 'browse']);
        Route::get('/workers/{user}', [WorkerProfileController::class, 'show']);

        // Skills & Categories.
        //
        // The writes are throttled hard because both tables are global: a row
        // created here shows up in every user's picker immediately and there is
        // no moderation queue for them. Ten an hour is far past what someone
        // adding a genuinely missing trade needs, and useless for defacement.
        // Categories are additionally capped per account in the controller;
        // skills have no created_by column to cap against.
        Route::get('/skills',     [SkillController::class, 'index']);
        Route::post('/skills',    [SkillController::class, 'store'])->middleware('throttle:taxonomy');
        Route::get('/categories', [CategoryController::class, 'index']);
        Route::post('/categories', [CategoryController::class, 'store'])->middleware('throttle:taxonomy');

        // Worker Profile
        Route::post('/worker/profile/complete-setup',              [WorkerProfileController::class, 'completeSetup']);
        Route::delete('/worker/profile',                           [WorkerProfileController::class, 'deleteProfile']);
        Route::put('/worker/profile',                              [WorkerProfileController::class, 'updateBasicInfo']);
        Route::post('/worker/profile/photo',                       [WorkerProfileController::class, 'uploadPhoto']);

        // Resume. Stored privately and served only through the download route,
        // which checks the caller — a CV carries a phone number, home address
        // and full work history, so it is never a public storage URL.
        Route::post('/worker/profile/resume',   [WorkerProfileController::class, 'uploadResume']);
        Route::delete('/worker/profile/resume', [WorkerProfileController::class, 'deleteResume']);
        Route::get('/workers/{user}/resume',    [WorkerProfileController::class, 'downloadResume']);
        // NOTE: a parallel /worker-profile/* family used to live here. Six of its
        // routes were bound to controller methods that never existed (show, update,
        // attachSkill, detachSkill, createExperience, createCertification) and one
        // had trailing whitespace in the method name — all of them 500'd on call.
        // Every route it offered is served by the /worker/* endpoints below, which
        // are what the app actually uses.


        // Worker Skills
        Route::get('/worker/skills',            [WorkerProfileController::class, 'getSkills']);
        Route::post('/worker/skills',           [WorkerProfileController::class, 'addSkill']);
        Route::put('/worker/skills/{id}',       [WorkerProfileController::class, 'updateSkill']);
        Route::delete('/worker/skills/{id}',    [WorkerProfileController::class, 'deleteSkill']);
        
        // Worker Certifications
        Route::get('/worker/certifications',        [WorkerProfileController::class, 'getCertifications']);
        Route::post('/worker/certifications',       [WorkerProfileController::class, 'addCertification']);
        Route::put('/worker/certifications/{id}',   [WorkerProfileController::class, 'updateCertification']);
        Route::delete('/worker/certifications/{id}', [WorkerProfileController::class, 'deleteCertification']);
        
        // Worker Licenses
        Route::get('/worker/licenses',          [WorkerProfileController::class, 'getLicenses']);
        Route::post('/worker/licenses',         [WorkerProfileController::class, 'addLicense']);
        Route::put('/worker/licenses/{id}',     [WorkerProfileController::class, 'updateLicense']);
        Route::delete('/worker/licenses/{id}',  [WorkerProfileController::class, 'deleteLicense']);
        
        // Worker License Examinations
        Route::get('/worker/license-examinations',          [WorkerProfileController::class, 'getLicenseExaminations']);
        Route::post('/worker/license-examinations',         [WorkerProfileController::class, 'addLicenseExamination']);
        Route::put('/worker/license-examinations/{id}',     [WorkerProfileController::class, 'updateLicenseExamination']);
        Route::delete('/worker/license-examinations/{id}',  [WorkerProfileController::class, 'deleteLicenseExamination']);
        
        // Worker Experiences
        Route::get('/worker/experiences',           [WorkerProfileController::class, 'getExperiences']);
        Route::post('/worker/experiences',          [WorkerProfileController::class, 'addExperience']);
        Route::put('/worker/experiences/{id}',      [WorkerProfileController::class, 'updateExperience']);
        Route::delete('/worker/experiences/{id}',   [WorkerProfileController::class, 'deleteExperience']);

        // Employer Profile
        Route::post('/employer-profile/complete-setup', [EmployerProfileController::class, 'completeSetup']);
        Route::delete('/employer-profile',              [EmployerProfileController::class, 'deleteProfile']);
        Route::get('/employer-profile',         [EmployerProfileController::class, 'index']);
        Route::post('/employer-profile',        [EmployerProfileController::class, 'store']);
        Route::put('/employer-profile',         [EmployerProfileController::class, 'update']);
        Route::post('/employer-profile/image',  [EmployerProfileController::class, 'uploadImage']);
        Route::get('/employers/{user}',         [EmployerProfileController::class, 'show']);

        // Jobs
        Route::get('/jobs',                     [JobController::class, 'index']);
        Route::post('/jobs',                    [JobController::class, 'store'])
            ->middleware('verified:employer');
        Route::get('/jobs/my',                  [JobController::class, 'myJobs']);
        Route::get('/jobs/{job}',               [JobController::class, 'show']);
        Route::put('/jobs/{job}',               [JobController::class, 'update']);
        Route::patch('/jobs/{job}/status',      [JobController::class, 'changeStatus']);
        Route::delete('/jobs/{job}',            [JobController::class, 'destroy']);
        Route::post('/jobs/{job}/save',         [JobController::class, 'save']);
        Route::delete('/jobs/{job}/save',       [JobController::class, 'unsave']);
        Route::get('/jobs/{job}/matches',       [JobController::class, 'matches']);
        Route::get('/jobs/{job}/applicants',    [ApplicationController::class, 'jobApplicants']);
        Route::post('/jobs/{job}/apply',        [ApplicationController::class, 'apply'])
            ->middleware('verified:worker');
        Route::post('/jobs/{job}/invite',       [InvitationController::class, 'send'])
            ->middleware('verified:employer');

        // Saved Jobs
        Route::get('/saved-jobs', [JobController::class, 'savedJobs']);

        // Applications
        Route::get('/my-applications',                      [ApplicationController::class, 'myApplications']);
        // Either party marks their side done. Which side is derived from the
        // job, never taken from the request.
        Route::patch('/applications/{application}/complete', [ApplicationController::class, 'complete']);
        Route::delete('/applications/{application}',        [ApplicationController::class, 'withdraw']);
        Route::patch('/applications/{application}/accept',  [ApplicationController::class, 'accept']);
        Route::patch('/applications/{application}/reject',  [ApplicationController::class, 'reject']);

        // Worker location sharing during an active hire. Consent lives on the
        // application, so every route is scoped to one — there is deliberately
        // no account-wide "where is this worker" endpoint.
        Route::get('/applications/{application}/tracking',         [JobTrackingController::class, 'show']);
        Route::post('/applications/{application}/tracking',        [JobTrackingController::class, 'start']);
        Route::delete('/applications/{application}/tracking',      [JobTrackingController::class, 'stop']);
        Route::post('/applications/{application}/tracking/ping',   [JobTrackingController::class, 'ping']);

        // Invitations
        Route::get('/my-invitations',                       [InvitationController::class, 'myInvitations']);
        Route::patch('/invitations/{invitation}/accept',    [InvitationController::class, 'accept'])
            ->middleware('verified:worker');
        Route::patch('/invitations/{invitation}/decline',   [InvitationController::class, 'decline']);

        // Messaging
        Route::get('/conversations',                            [ConversationController::class, 'index']);
        Route::get('/conversations/{conversation}/messages',    [ConversationController::class, 'messages']);
        Route::post('/conversations/{conversation}/messages',   [ConversationController::class, 'sendMessage']);
        Route::patch('/conversations/{conversation}/read',      [ConversationController::class, 'markRead']);

        /*
            Credits. Read only — nothing here moves a balance.

            Spending lives with the thing being paid for, so a charge and the
            action it bought commit together or not at all. An endpoint that
            just took credits would be able to take them for nothing.
        */
        Route::get('/credits/wallet',       [CreditController::class, 'wallet']);
        Route::get('/credits/transactions', [CreditController::class, 'transactions']);
        Route::post('/credits/claim',       [CreditController::class, 'claim']);
        Route::post('/credits/checkout',    [CreditCheckoutController::class, 'checkout'])
            // Topping up is spending. Claiming a grant is not - that route
            // stays open so a balance still accrues while documents are
            // being reviewed, and a newly verified user is not starting
            // from zero because an admin took three days.
            ->middleware(['throttle:credits-checkout', 'verified:any']);

        /*
            There is deliberately no /credits/confirm.

            An endpoint the app could call to say "I paid" would be a way to
            mint credits for free, however carefully it checked. Only the
            webhook and the reconciler grant, and both verify with PayMongo
            rather than trusting anyone.
        */

        // Notifications. `audience` mirrors the app's worker/employer mode, so
        // a hybrid account doesn't see the other side's alerts.
        Route::get('/notifications',                    [NotificationController::class, 'index']);
        Route::get('/notifications/unread-count',       [NotificationController::class, 'unreadCount']);

        // Who has been looking at you. Own account only — see the controller.
        Route::get('/profile-views/summary',            [ProfileViewController::class, 'summary']);
        Route::post('/notifications/read-all',          [NotificationController::class, 'readAll']);
        Route::patch('/notifications/{notification}/read', [NotificationController::class, 'markRead']);

        // Reviews. The status route is what makes the pair mutual rather than
        // two unrelated submissions: it tells each side where the other is.
        Route::post('/reviews', [ReviewController::class, 'store']);
        Route::get('/jobs/{job}/review-status', [ReviewController::class, 'status']);

        // Reports. Throttled: filing is cheap and the queue is read by people,
        // so a loop here costs an administrator's afternoon, not a server.
        Route::get('/report-reasons', [ReportController::class, 'reasons']);
        Route::post('/reports', [ReportController::class, 'store'])
            ->middleware('throttle:reports');

        /*
            Email and phone verification.
            Throttled: these send real messages that cost money, and a code
            endpoint left open is a way to bill someone else's SMS credits.
        */
        Route::get('/contact-verification', [ContactVerificationController::class, 'status']);
        Route::middleware('throttle:verification-send')->group(function () {
            Route::post('/contact-verification/email/send', [ContactVerificationController::class, 'sendEmailCode']);
            Route::post('/contact-verification/phone/send', [ContactVerificationController::class, 'sendPhoneCode']);
        });
        // Guessing is bounded per code as well, but this stops someone working
        // through the million possibilities by requesting new codes.
        Route::middleware('throttle:verification-verify')->group(function () {
            Route::post('/contact-verification/email/verify', [ContactVerificationController::class, 'verifyEmailCode']);
            Route::post('/contact-verification/phone/verify', [ContactVerificationController::class, 'verifyPhoneCode']);
        });

        // Verifications
        Route::get('/verifications',  [VerificationController::class, 'index']);
        Route::post('/verifications', [VerificationController::class, 'store']);
        // Government IDs and selfies live on the private disk and are streamed
        // through here — owner or admin only. They used to sit on the public
        // disk with a guessable-once-seen URL and no check at all.
        Route::get('/verifications/{verification}/document/{side}',
            [VerificationDocumentController::class, 'show'])
            ->whereIn('side', ['front', 'back', 'selfie']);
    });
});
