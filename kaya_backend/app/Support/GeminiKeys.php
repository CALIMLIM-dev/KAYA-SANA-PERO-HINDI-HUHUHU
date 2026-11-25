<?php

namespace App\Support;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Several Gemini keys, used in turn.
 *
 * EMBEDDING_API_KEY may hold more than one key, separated by commas, each from
 * its own Google account (a quota is per project, so keys in one project share
 * it). The first key is used until Google refuses it for its quota (429) or
 * the key itself (401/403, or the 400 it sends for a key that does not exist);
 * that key then rests and the next one answers.
 * Every key gives the same vectors for the same word, so nothing stored
 * changes. Used by embeddings, skill linking, the assistant and the safety
 * check - everything that called Gemini with the one key.
 */
class GeminiKeys
{
    /** @return list<string> */
    public static function all(): array
    {
        $keys = array_map('trim', explode(',', (string) config('kaya.matching.api_key')));

        return array_values(array_unique(array_filter($keys, fn ($k) => $k !== '')));
    }

    /**
     * Sends with the first key that is not resting, moving on when a key is
     * refused. Returns the answer, the last refusal when every key was
     * refused, or null when every key is resting. A timeout is thrown as
     * before: that is the network, not the key.
     *
     * @param  callable(string): Response  $send
     */
    public static function send(callable $send): ?Response
    {
        $last = null;

        foreach (self::all() as $i => $key) {
            if (Cache::has(self::restKey($key))) {
                continue;
            }

            $response = $send($key);

            if (in_array($response->status(), [429, 401, 403], true) || self::isDeadKey($response)) {
                $minutes = $response->status() === 429 ? 60 : 24 * 60;
                Cache::put(self::restKey($key), $response->status(), now()->addMinutes($minutes));
                Log::warning('[gemini] key ' . ($i + 1) . ' refused (HTTP ' . $response->status() . "), resting {$minutes} min");
                $last = $response;

                continue;
            }

            return $response;
        }

        return $last;
    }

    /*
        Google answers a wrong or deleted key with 400, the same status as a
        badly written request. Only the key's own reason counts: resting
        every key over one bad request would switch everything off.
    */
    private static function isDeadKey(Response $response): bool
    {
        return $response->status() === 400
            && (str_contains($response->body(), 'API_KEY_INVALID')
                || str_contains($response->body(), 'API key not valid'));
    }

    private static function restKey(string $key): string
    {
        return 'gemini.key.rest.' . md5($key);
    }
}
