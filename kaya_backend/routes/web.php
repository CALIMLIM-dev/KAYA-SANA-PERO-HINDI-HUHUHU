<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\ReportController;
use App\Http\Controllers\Admin\SettingsController;
use App\Http\Controllers\Admin\UserManagementController;
use App\Http\Controllers\Admin\VerificationController;
use Illuminate\Support\Facades\Route;

// Redirect root to admin login
Route::get('/', fn () => redirect()->route('admin.login'));

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
        Route::post('/users/{user}/suspend', [UserManagementController::class, 'suspend'])->name('users.suspend');
        Route::post('/users/{user}/activate', [UserManagementController::class, 'activate'])->name('users.activate');

        Route::get('/verifications', [VerificationController::class, 'index'])->name('verifications.index');
        Route::get('/verifications/{verification}', [VerificationController::class, 'show'])->name('verifications.show');
        Route::post('/verifications/{verification}/approve', [VerificationController::class, 'approve'])->name('verifications.approve');
        Route::post('/verifications/{verification}/reject', [VerificationController::class, 'reject'])->name('verifications.reject');

        Route::get('/reports', [ReportController::class, 'index'])->name('reports.index');
        Route::post('/reports/{report}/resolve', [ReportController::class, 'resolve'])->name('reports.resolve');

        Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');
        Route::post('/settings', [SettingsController::class, 'update'])->name('settings.update');
    });
});
