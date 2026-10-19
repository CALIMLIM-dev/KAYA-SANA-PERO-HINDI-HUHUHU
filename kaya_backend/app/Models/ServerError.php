<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An error the server hit, for the Server Errors page. See the migration.
 */
class ServerError extends Model
{
    protected $fillable = ['hash', 'exception', 'message', 'file', 'line', 'method', 'url', 'user_id', 'trace', 'count', 'last_seen_at'];

    protected $casts = ['last_seen_at' => 'datetime'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /** Records one error. Never throws: it runs while something already went wrong. */
    public static function capture(\Throwable $e): void
    {
        try {
            $root = base_path() . DIRECTORY_SEPARATOR;
            $file = str_replace($root, '', $e->getFile());
            $hash = sha1(get_class($e) . '|' . $file . '|' . $e->getLine());
            $request = app()->runningInConsole() && ! app()->runningUnitTests() ? null : request();

            $row = static::firstOrNew(['hash' => $hash]);
            $row->fill([
                'exception'    => mb_substr(get_class($e), 0, 255),
                'message'      => mb_substr($e->getMessage(), 0, 2000),
                'file'         => mb_substr($file, 0, 255),
                'line'         => $e->getLine(),
                'method'       => $request?->method(),
                'url'          => $request ? mb_substr($request->fullUrl(), 0, 500) : 'console: ' . mb_substr(implode(' ', $_SERVER['argv'] ?? []), 0, 480),
                'user_id'      => $request?->user()?->id,
                'trace'        => mb_substr(str_replace($root, '', $e->getTraceAsString()), 0, 4000),
                'last_seen_at' => now(),
            ]);
            $row->count = $row->exists ? $row->count + 1 : 1;
            $row->save();
        } catch (\Throwable) {
            // The database may be the thing that failed.
        }
    }
}
