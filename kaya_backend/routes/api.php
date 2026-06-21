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

Route::prefix('v1')->group(function () {

    // ── Auth (public) ─────────────────────────────────────────────────────────
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login',    [AuthController::class, 'login']);

    // ── Authenticated ─────────────────────────────────────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me',      [AuthController::class, 'me']);

        // Skills & Categories (public read)
        Route::get('/skills',     [SkillController::class, 'index']);
        Route::get('/categories', [CategoryController::class, 'index']);

        // Worker Profile
        Route::get('/worker-profile',                              [WorkerProfileController::class, 'show']);
        Route::put('/worker-profile',                              [WorkerProfileController::class, 'update']);
        Route::post('/worker-profile/skills',                      [WorkerProfileController::class, 'attachSkill']);
        Route::delete('/worker-profile/skills/{skill}',            [WorkerProfileController::class, 'detachSkill']);
        Route::post('/worker-profile/experiences',                 [WorkerProfileController::class, 'createExperience']);
        Route::put('/worker-profile/experiences/{experience}',     [WorkerProfileController::class, 'updateExperience']);
        Route::delete('/worker-profile/experiences/{experience}',  [WorkerProfileController::class, 'deleteExperience']);
        Route::post('/worker-profile/certifications',              [WorkerProfileController::class, 'createCertification']);
        Route::delete('/worker-profile/certifications/{cert}',     [WorkerProfileController::class, 'deleteCertification']);
        Route::post('/worker-profile/photo',                       [WorkerProfileController::class, 'uploadPhoto']);

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
    });
});
