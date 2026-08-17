<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Verification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Serves verification documents from private storage.
 *
 * These files — a government ID photograph paired with a liveness selfie —
 * were written to the `public` disk and served straight off the filesystem by
 * the web server, with the storage path returned verbatim in the API response.
 * Anything that captured one response turned into a permanent, unauthenticated
 * and unrevocable URL to somebody's national ID. That pair is exactly the KYC
 * bundle used to open accounts elsewhere.
 *
 * The pattern here is copied from WorkerProfileController::downloadResume,
 * which the same codebase already gets right: private disk, streamed through a
 * controller that checks entitlement, path never serialised.
 *
 * Only two parties may read one: the person it belongs to, and an admin
 * reviewing it. Not employers, not the worker's clients, not anyone else.
 */
class VerificationDocumentController extends Controller
{
    /** Which file on the record is being asked for. */
    private const SIDES = ['front' => 'document_front_url', 'back' => 'document_back_url', 'selfie' => 'selfie_url'];

    public function show(Request $request, Verification $verification, string $side)
    {
        if (! array_key_exists($side, self::SIDES)) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Unknown document.',
            ], 404);
        }

        $viewer = $request->user();

        if ($viewer->id !== $verification->user_id && ! $viewer->isAdmin()) {
            /*
                404 rather than 403.

                A 403 confirms the record exists, which turns this endpoint into
                a way to test whether a given user has submitted an ID at all.
            */
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Not found.',
            ], 404);
        }

        $path = $verification->{self::SIDES[$side]};

        if (blank($path) || ! Storage::disk(config('filesystems.documents'))->exists($path)) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'The file is missing.',
            ], 404);
        }

        // Inline rather than as a download: the admin reviews these on screen,
        // and the owner is only confirming what they sent.
        return Storage::disk(config('filesystems.documents'))->response($path);
    }
}
