<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    Sets users.avatar to the picture each account chose last.

    Until now only the worker photo upload wrote users.avatar; an employer
    picture went to employer_profiles.image_path alone. Both uploads write
    it from here on, and this brings existing accounts in line so nobody
    has to upload again to see the picture they already chose.

    Which one was chosen last is not recorded, so the profile row's
    updated_at stands in for it. Close enough, once.
*/
return new class extends Migration
{
    public function up(): void
    {
        $rows = DB::table('users')
            ->leftJoin('worker_profiles', 'worker_profiles.user_id', '=', 'users.id')
            ->leftJoin('employer_profiles', 'employer_profiles.user_id', '=', 'users.id')
            ->select([
                'users.id', 'users.avatar',
                'worker_profiles.profile_photo_path', 'worker_profiles.updated_at as worker_at',
                'employer_profiles.image_path', 'employer_profiles.updated_at as employer_at',
            ])
            ->where(fn ($q) => $q->whereNotNull('worker_profiles.profile_photo_path')
                ->orWhereNotNull('employer_profiles.image_path'))
            ->get();

        foreach ($rows as $row) {
            $worker = filled($row->profile_photo_path) ? $row->profile_photo_path : null;
            $logo = filled($row->image_path) ? $row->image_path : null;

            $latest = match (true) {
                $worker === null => $logo,
                $logo === null => $worker,
                default => ($row->employer_at ?? '') > ($row->worker_at ?? '') ? $logo : $worker,
            };

            if ($latest !== null && $latest !== $row->avatar) {
                DB::table('users')->where('id', $row->id)->update(['avatar' => $latest]);
            }
        }
    }

    public function down(): void
    {
        // Nothing to undo: the column held a picture before and holds one after.
    }
};
