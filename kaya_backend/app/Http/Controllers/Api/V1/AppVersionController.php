<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

/**
 * What build the server expects, so the app can check itself.
 *
 * KAYA is handed out as an APK rather than through a store, so nothing updates
 * anybody automatically. A tester can be three builds behind, reporting a bug
 * that was fixed that morning, and neither of us can tell from the report.
 *
 * Public and unauthenticated on purpose: the check has to work on the login
 * screen, before there is a token, which is exactly when somebody with a very
 * old build is most likely to be stuck.
 */
class AppVersionController extends Controller
{
    public function show(Request $request, ?string $version = null)
    {
        $minimum = (string) config('kaya.app.minimum_version');
        $latest  = (string) config('kaya.app.latest_version');

        /*
            The app sends what it is running, and the server answers about it.

            Doing the comparison here rather than in the app means the rule can
            change without a release - which matters, because the clients that
            need the rule most are the ones too old to have the new rule in
            them.

            An absent or unparseable version is treated as too old. A build
            that cannot say what it is predates this endpoint entirely.
        */
        $current = (string) ($version ?? $request->query('version', ''));

        $supported = $current !== ''
            && version_compare($this->normalise($current), $this->normalise($minimum), '>=');

        $isLatest = $current !== ''
            && version_compare($this->normalise($current), $this->normalise($latest), '>=');

        return response()->json([
            'success' => true,
            'data' => [
                'minimum_version' => $minimum,
                'latest_version'  => $latest,
                'download_url'    => config('kaya.app.download_url'),

                // What the app should do, decided here rather than inferred
                // from the numbers by every client that ever ships.
                'supported'       => $supported,
                'update_required' => ! $supported,
                'update_available' => $supported && ! $isLatest,
            ],
            'message' => $supported
                ? 'Version accepted'
                : 'This version of KAYA is out of date.',
        ]);
    }

    /**
     * Drops a build number so "1.2.1+4" compares as "1.2.1".
     *
     * Flutter writes the build after a plus and it is not part of the version
     * anyone reasons about; leaving it in makes version_compare treat the
     * whole string as unparseable.
     */
    private function normalise(string $version): string
    {
        return trim(explode('+', $version)[0]);
    }
}
