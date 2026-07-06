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
use App\Http\Controllers\Api\V1\VerificationController;

Route::prefix('v1')->group(function () {

    // ── Auth (public) ─────────────────────────────────────────────────────────
    Route::post('/register',      [AuthController::class, 'register']);
    Route::post('/login',         [AuthController::class, 'login']);
    Route::post('/google-login',  [AuthController::class, 'googleLogin']);
    
    // Password Reset
    Route::post('/forgot-password',       [AuthController::class, 'forgotPassword']);
    Route::post('/verify-reset-code',     [AuthController::class, 'verifyResetCode']);
    Route::post('/reset-password',        [AuthController::class, 'resetPassword']);

    // ── Authenticated ─────────────────────────────────────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me',      [AuthController::class, 'me']);
        Route::get('/check-status', [AuthController::class, 'checkStatus']);
        Route::patch('/me',    [AuthController::class, 'updateMe']);
        Route::get('/user',    [AuthController::class, 'user']);

        // Skills & Categories (public read)
        Route::get('/skills',     [SkillController::class, 'index']);
        Route::get('/categories', [CategoryController::class, 'index']);

        // Worker Profile
        Route::put('/worker/profile',                              [WorkerProfileController::class, 'updateBasicInfo']);
        Route::post('/worker/profile/photo',                       [WorkerProfileController::class, 'uploadPhoto']);
        Route::get('/worker-profile',                              [WorkerProfileController::class, 'show']);
        Route::put('/worker-profile',                              [WorkerProfileController::class, 'update']);
        Route::post('/worker-profile/skills',                      [WorkerProfileController::class, 'attachSkill']);
        Route::delete('/worker-profile/skills/{skill}',            [WorkerProfileController::class, 'detachSkill']);
        Route::post('/worker-profile/experiences',                 [WorkerProfileController::class, 'createExperience']);
        Route::put('/worker-profile/experiences/{experience}',     [WorkerProfileController::class, 'updateExperience']);
        Route::delete('/worker-profile/experiences/{experience}',  [WorkerProfileController::class, 'deleteExperience   ']);
        Route::post('/worker-profile/certifications',              [WorkerProfileController::class, 'createCertification']);
        Route::delete('/worker-profile/certifications/{cert}',     [WorkerProfileController::class, 'deleteCertification']);
        Route::post('/worker-profile/photo',                       [WorkerProfileController::class, 'uploadPhoto']);
        
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
        Route::get('/employer-profile',         [EmployerProfileController::class, 'show']);
        Route::put('/employer-profile',         [EmployerProfileController::class, 'update']);
        Route::post('/employer-profile/logo',   [EmployerProfileController::class, 'uploadLogo']);

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
