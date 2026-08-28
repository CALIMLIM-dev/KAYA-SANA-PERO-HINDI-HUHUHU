<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\ReportController;
use App\Http\Controllers\Admin\AnalyticsController;
use App\Http\Controllers\Admin\ReportExportController;
use App\Http\Controllers\Admin\SettingsController;
use App\Http\Controllers\Admin\UserManagementController;
use App\Http\Controllers\Admin\VerificationController;
use App\Http\Controllers\LegalController;
use Illuminate\Support\Facades\Route;

// Redirect root to admin login
Route::get('/', fn () => redirect()->route('admin.login'));

// Public legal pages. These have to resolve for the Google sign-in consent
// screen, which links to them by URL — see LegalController.
Route::get('/terms', [LegalController::class, 'terms'])->name('legal.terms');
Route::get('/privacy', [LegalController::class, 'privacy'])->name('legal.privacy');

// Fallback login route (Laravel's default redirect)
Route::get('/login', fn () => redirect()->route('admin.login'))->name('login');

Route::prefix('admin')->name('admin.')->group(function () {

    // Public — login
    Route::get('/login', [AdminAuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AdminAuthController::class, 'login']);

    // Protected — everything else
    Route::middleware(['auth', 'admin.web'])->group(function () {
        Route::post('/logout', [AdminAuthController::class, 'logout'])->name('logout');

        Route::get('/', [DashboardController::class, 'index'])->name('dashboard');
        Route::get('/dashboard', [DashboardController::class, 'index']);

        Route::get('/users', [UserManagementController::class, 'index'])->name('users.index');
        Route::get('/users/{user}', [UserManagementController::class, 'show'])->name('users.show');
        // Certificate and licence scans, streamed rather than linked - see the
        // controller for why asset('storage/...') was the wrong shape.
        Route::get('/users/{user}/document/{kind}/{id}', [UserManagementController::class, 'document'])
            ->whereIn('kind', ['certification', 'licence'])
            ->whereNumber('id')
            ->name('users.document');
        Route::post('/users/{user}/suspend', [UserManagementController::class, 'suspend'])->name('users.suspend');
        Route::post('/users/{user}/activate', [UserManagementController::class, 'activate'])->name('users.activate');

        Route::get('/verifications', [VerificationController::class, 'index'])->name('verifications.index');
        Route::get('/verifications/{verification}', [VerificationController::class, 'show'])->name('verifications.show');
        // Government IDs moved to private storage, so the panel can no longer
        // link straight at /storage/... — it streams them through here instead.
        Route::get('/verifications/{verification}/document/{side}', [VerificationController::class, 'document'])
            ->whereIn('side', ['front', 'back', 'selfie'])
            ->name('verifications.document');
        Route::post('/verifications/{verification}/approve', [VerificationController::class, 'approve'])->name('verifications.approve');
        Route::post('/verifications/{verification}/reject', [VerificationController::class, 'reject'])->name('verifications.reject');

        Route::get("/analytics", [AnalyticsController::class, "index"])->name("analytics.index");

        // Report generation. Separate from /reports, which is the moderation
        // queue for abuse reports — a different feature that happens to share
        // the word.
        Route::prefix('exports')->name('exports.')->group(function () {
            Route::get('/', [ReportExportController::class, 'index'])->name('index');
            Route::get('/users', [ReportExportController::class, 'users'])->name('users');
            Route::get('/jobs', [ReportExportController::class, 'jobs'])->name('jobs');
            Route::get('/applicants', [ReportExportController::class, 'applicants'])->name('applicants');
            Route::get('/hires', [ReportExportController::class, 'hires'])->name('hires');
            Route::get('/verifications', [ReportExportController::class, 'verifications'])->name('verifications');
            Route::get('/top-workers', [ReportExportController::class, 'topWorkers'])->name('top-workers');
            Route::get('/skill-demand', [ReportExportController::class, 'skillDemand'])->name('skill-demand');
            Route::get('/categories', [ReportExportController::class, 'categories'])->name('categories');
        });

        Route::get('/reports', [ReportController::class, 'index'])->name('reports.index');
        Route::get('/reports/{report}', [ReportController::class, 'show'])->name('reports.show');
        Route::post('/reports/{report}/resolve', [ReportController::class, 'resolve'])->name('reports.resolve');
        // Suspends the reported account and closes the report together, so the
        // two cannot fall out of step.
        Route::post('/reports/{report}/suspend', [ReportController::class, 'suspend'])->name('reports.suspend');

        Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');
        Route::post('/settings', [SettingsController::class, 'update'])->name('settings.update');
    });
});

/*
    Where PayMongo sends the browser after paying.

    Grants nothing — see the note in the view. The credits arrive through the
    webhook or the reconciler, so this page can be opened by anyone, at any
    time, without effect.
*/
Route::view('/pay/return', 'pay.return');
