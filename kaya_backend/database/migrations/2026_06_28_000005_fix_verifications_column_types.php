<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Change document_type from enum to varchar to accept any type string
        // Change status enum to include 'verified' (was 'approved' before)
        DB::statement("ALTER TABLE verifications 
            MODIFY COLUMN document_type VARCHAR(100) NOT NULL DEFAULT 'government_id',
            MODIFY COLUMN status ENUM('pending', 'verified', 'rejected') DEFAULT 'pending'
        ");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE verifications 
            MODIFY COLUMN document_type ENUM('national_id','passport','drivers_license','barangay_clearance','philsys_id') DEFAULT 'national_id',
            MODIFY COLUMN status ENUM('pending','approved','rejected') DEFAULT 'pending'
        ");
    }
};
