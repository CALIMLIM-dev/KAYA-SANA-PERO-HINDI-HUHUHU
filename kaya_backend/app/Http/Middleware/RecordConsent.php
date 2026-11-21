<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/**
 * Records that the person ticked the consent box before an upload, once the
 * upload has succeeded. `consent:verification` names the subject after the
 * verification type sent (government_id, business_reg ...); any other
 * parameter is the subject itself.
 *
 * The app keeps the send button off until the box is ticked; this is the
 * record of it, with the Terms version they agreed to (RA 10173 asks a
 * controller to be able to show consent was given).
 */
class RecordConsent
{
    public function handle(Request $request, Closure $next, string $subject): Response
    {
        $response = $next($request);

        if ($response->isSuccessful() && $request->boolean('consent') && $request->user()) {
            DB::table('consents')->insert([
                'user_id' => $request->user()->id,
                'subject' => $subject === 'verification' ? (string) $request->input('type', 'verification') : $subject,
                'terms_version' => self::termsVersion(),
                'created_at' => now(),
            ]);
        }

        return $response;
    }

    /** The "Last updated" of the Terms, from the copy kaya:legal-sync writes. */
    public static function termsVersion(): string
    {
        $legal = json_decode((string) @file_get_contents(resource_path('legal_content.json')), true);

        return substr((string) ($legal['updated'] ?? 'unknown'), 0, 40);
    }
}
