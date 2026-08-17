<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\WorkerProfileController;
use App\Http\Controllers\Api\V1\EmployerProfileController;
use App\Http\Controllers\Api\V1\JobController;
use App\Http\Controllers\Api\V1\ApplicationController;
use App\Http\Controllers\Api\V1\InvitationController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\ReviewController;
use App\Http\Controllers\Api\V1\SkillController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\LocationController;
use App\Http\Controllers\Api\V1\VerificationController;

Route::prefix('v1')->group(function () {

    // ── Auth (public) ─────────────────────────────────────────────────────────
    // Throttled per IP. Credential-guessing endpoints get the tighter limit;
    // verify-reset-code especially, since the code is only 6 digits and is valid
    // for 15 minutes (~1e6 space, trivially brute-forceable unthrottled).
    Route::middleware('throttle:10,1')->group(function () {
        Route::post('/login',        [AuthController::class, 'login']);
        Route::post('/google-login', [AuthController::class, 'googleLogin']);
    });

    Route::middleware('throttle:5,1')->group(function () {
        Route::post('/register',          [AuthController::class, 'register']);
        Route::post('/forgot-password',   [AuthController::class, 'forgotPassword']);
        Route::post('/verify-reset-code', [AuthController::class, 'verifyResetCode']);
        Route::post('/reset-password',    [AuthController::class, 'resetPassword']);
    });

    // ── Authenticated ─────────────────────────────────────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me',      [AuthController::class, 'me']);
        Route::get('/check-status', [AuthController::class, 'checkStatus']);
        Route::patch('/me',    [AuthController::class, 'updateMe']);
        Route::get('/user',    [AuthController::class, 'user']);

        // Locations (PSGC lookup for the location picker)
        Route::get('/locations/search',  [LocationController::class, 'search']);
        Route::get('/locations/nearest', [LocationController::class, 'nearest']);
        Route::get('/locations/{location}', [LocationController::class, 'show']);

        // Worker directory (employer-mode browse/search)
        Route::get('/workers', [WorkerProfileController::class, 'browse']);
        Route::get('/workers/{user}', [WorkerProfileController::class, 'show']);

        // Skills & Categories
        Route::get('/skills',     [SkillController::class, 'index']);
        Route::post('/skills',    [SkillController::class, 'store']);
        Route::get('/categories', [CategoryController::class, 'index']);
        Route::post('/categories', [CategoryController::class, 'store']);

        // Worker Profile
        Route::post('/worker/profile/complete-setup',              [WorkerProfileController::class, 'completeSetup']);
        Route::delete('/worker/profile',                           [WorkerProfileController::class, 'deleteProfile']);
        Route::put('/worker/profile',                              [WorkerProfileController::class, 'updateBasicInfo']);
        Route::post('/worker/profile/photo',                       [WorkerProfileController::class, 'uploadPhoto']);
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
        Route::post('/jobs',                    [JobController::class, 'store']);
        Route::get('/jobs/my',                  [JobController::class, 'myJobs']);
        Route::get('/jobs/{job}',               [JobController::class, 'show']);
        Route::put('/jobs/{job}',               [JobController::class, 'update']);
        Route::patch('/jobs/{job}/status',      [JobController::class, 'changeStatus']);
        Route::delete('/jobs/{job}',            [JobController::class, 'destroy']);
        Route::post('/jobs/{job}/save',         [JobController::class, 'save']);
        Route::delete('/jobs/{job}/save',       [JobController::class, 'unsave']);
        Route::get('/jobs/{job}/matches',       [JobController::class, 'matches']);
        Route::get('/jobs/{job}/applicants',    [ApplicationController::class, 'jobApplicants']);
        Route::post('/jobs/{job}/apply',        [ApplicationController::class, 'apply']);
        Route::post('/jobs/{job}/invite',       [InvitationController::class, 'send']);

        // Saved Jobs
        Route::get('/saved-jobs', [JobController::class, 'savedJobs']);

        // Applications
        Route::get('/my-applications',                      [ApplicationController::class, 'myApplications']);
        Route::delete('/applications/{application}',        [ApplicationController::class, 'withdraw']);
        Route::patch('/applications/{application}/accept',  [ApplicationController::class, 'accept']);
        Route::patch('/applications/{application}/reject',  [ApplicationController::class, 'reject']);

        // Invitations
        Route::get('/my-invitations',                       [InvitationController::class, 'myInvitations']);
        Route::patch('/invitations/{invitation}/accept',    [InvitationController::class, 'accept']);
        Route::patch('/invitations/{invitation}/decline',   [InvitationController::class, 'decline']);

        // Messaging
        Route::get('/conversations',                            [ConversationController::class, 'index']);
        Route::get('/conversations/{conversation}/messages',    [ConversationController::class, 'messages']);
        Route::post('/conversations/{conversation}/messages',   [ConversationController::class, 'sendMessage']);
        Route::patch('/conversations/{conversation}/read',      [ConversationController::class, 'markRead']);

        // Reviews
        Route::post('/reviews', [ReviewController::class, 'store']);

        // Verifications
        Route::get('/verifications',  [VerificationController::class, 'index']);
        Route::post('/verifications', [VerificationController::class, 'store']);
    });
});
