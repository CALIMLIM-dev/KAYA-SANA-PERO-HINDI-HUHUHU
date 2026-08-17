<?php

namespace App\Services;

use Illuminate\Database\Eloquent\Builder as EloquentBuilder;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Streams a query out as a CSV download.
 *
 * Streamed rather than assembled in memory. An export is the one place in an
 * admin panel that grows without limit — a year of applications is a row per
 * application — and building the whole file as a string first means the request
 * dies on memory or the time limit exactly when the data is most worth having.
 * Rows are fetched in chunks and written straight to the output buffer, so peak
 * memory stays flat no matter how many rows there are.
 *
 * Each report produces its own file with its own columns. Merging several
 * reports into one sheet forces whoever opens it to separate them again by
 * hand, and it makes the header row meaningless.
 */
class CsvExporter
{
    /** Rows fetched per round trip. Large enough to be quick, small enough to stay flat. */
    private const CHUNK = 500;

    /**
     * @param  array<int, string>  $headers  Column titles, in order.
     * @param  callable(object): array<int, mixed>  $mapRow  Turns one record into one row.
     */
    public function stream(
        string $filename,
        array $headers,
        EloquentBuilder|QueryBuilder $query,
        callable $mapRow,
    ): StreamedResponse {
        return response()->stream(
            function () use ($headers, $query, $mapRow) {
                $out = fopen('php://output', 'w');

                // Excel assumes the system encoding unless a UTF-8 byte order
                // mark says otherwise, which mangles the ñ in place names like
                // Dasmariñas and Cabuyao's neighbours.
                fwrite($out, "\xEF\xBB\xBF");

                fputcsv($out, $headers);

                $query->chunk(self::CHUNK, function ($rows) use ($out, $mapRow) {
                    foreach ($rows as $row) {
                        fputcsv($out, $mapRow($row));
                    }
                    // Push each chunk to the client rather than letting it pool
                    // in the buffer, so a long export starts downloading
                    // immediately instead of appearing to hang.
                    flush();
                });

                fclose($out);
            },
            200,
            [
                'Content-Type'        => 'text/csv; charset=UTF-8',
                'Content-Disposition' => 'attachment; filename="' . $filename . '"',
                // Without this the browser can serve a stale export from cache
                // and the admin sees yesterday's numbers with today's filename.
                'Cache-Control'       => 'no-store, no-cache, must-revalidate',
                'Pragma'              => 'no-cache',
            ],
        );
    }

    /**
     * Names a file after its report and the day it was taken.
     *
     * Someone exporting the same report weekly ends up with a folder of files;
     * dating them is the difference between a usable archive and eight copies
     * of "report.csv".
     */
    public function filename(string $report, ?string $from = null, ?string $to = null): string
    {
        $range = $from && $to ? "_{$from}_to_{$to}" : '_' . now()->format('Y-m-d');

        return "kaya_{$report}{$range}.csv";
    }
}
