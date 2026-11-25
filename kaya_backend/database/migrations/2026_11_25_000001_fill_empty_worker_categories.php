<?php

use App\Models\WorkerProfile;
use Illuminate\Database\Migrations\Migration;

/*
    Workers left without a category by one that was deleted take the category
    of the skills they still have. From here on it is filled as it happens.
*/
return new class extends Migration
{
    public function up(): void
    {
        WorkerProfile::fillCategories(WorkerProfile::whereNull('category_id')->pluck('user_id'));
    }

    public function down(): void
    {
        // Which ones were empty is not kept.
    }
};
