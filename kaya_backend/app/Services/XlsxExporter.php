<?php

namespace App\Services;

use Illuminate\Database\Eloquent\Builder as EloquentBuilder;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

/*
    A query out as an Excel workbook, laid out to be read.

    The exports were CSV, and a CSV cannot say anything about how it looks:
    every column opened at the same narrow width, dates were text Excel would
    not sort, a phone number lost its leading 0, and there was nowhere to
    say what the file was or which period it covered. Each file is now a
    real .xlsx: a title and its period on top, bold headers that stay put
    while scrolling and carry filters, columns as wide as what is in them,
    dates and numbers as dates and numbers, phones as text.

    Written by hand rather than with a spreadsheet package. An .xlsx is a
    zip of a few XML files, the zip here is the plain uncompressed kind,
    and doing it this way needs nothing installed on the server - not a
    composer package, not PHP's zip extension.

    Rows are fetched in chunks and spooled to a temporary stream, so memory
    stays flat however many rows there are; the widths and the filter range
    need the last row, so the sheet is assembled once every row is in.
*/
class XlsxExporter
{
    private const CHUNK = 500;

    /** Column type => cell style. See styles(). */
    private const STYLE = ['text' => 0, 'datetime' => 4, 'int' => 5, 'decimal' => 6, 'money' => 7, 'date' => 8];

    /** Rows above the data: title, period, a gap, then the headers. */
    private const HEADER_ROW = 4;

    /**
     * @param  array<string, string>  $columns  Header => type: text, int, decimal, money, date or datetime.
     * @param  callable(object): array<int, mixed>  $mapRow  One record to one row, in column order.
     */
    public function download(
        string $report,
        string $title,
        array $columns,
        // A query, read in chunks, or rows already worked out (a page's table).
        EloquentBuilder|QueryBuilder|iterable $query,
        callable $mapRow,
        ?string $from = null,
        ?string $to = null,
        ?string $periodNote = null,
    ): StreamedResponse {
        return response()->stream(
            fn () => $this->write($title, $columns, $query, $mapRow, $from, $to, $periodNote),
            200,
            [
                'Content-Type'        => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'Content-Disposition' => 'attachment; filename="' . $this->filename($report, $from, $to) . '"',
                // Without this the browser can serve a stale export from cache
                // and the admin sees yesterday's numbers with today's filename.
                'Cache-Control'       => 'no-store, no-cache, must-revalidate',
                'Pragma'              => 'no-cache',
            ],
        );
    }

    /** kaya_users_2026-10-14.xlsx, or with the range when there is one. */
    public function filename(string $report, ?string $from = null, ?string $to = null): string
    {
        $range = $from && $to ? "_{$from}_to_{$to}" : '_' . now()->format('Y-m-d');

        return "kaya_{$report}{$range}.xlsx";
    }

    private function write(string $title, array $columns, $query, callable $mapRow, ?string $from, ?string $to, ?string $periodNote): void
    {
        $headers = array_keys($columns);
        $types = array_values($columns);
        $widths = array_map(fn ($h) => mb_strlen($h), $headers);

        $body = fopen('php://temp', 'w+');
        $row = self::HEADER_ROW;

        $each = function ($records) use (&$row, &$widths, $body, $types, $mapRow) {
            foreach ($records as $record) {
                $row++;
                fwrite($body, $this->row($row, $mapRow($record), $types, $widths));
            }
        };

        is_iterable($query) ? $each($query) : $query->chunk(self::CHUNK, $each);

        $count = $row - self::HEADER_ROW;
        $last = $this->column(count($headers)) . max($row, self::HEADER_ROW + 1);

        // "Registered: Jul 16, 2026 to Oct 14, 2026" - what the range was applied to.
        $what = $periodNote ? ucfirst($periodNote) : 'Period';
        $period = match (true) {
            $from && $to => "{$what}: " . $this->day($from) . ' to ' . $this->day($to),
            (bool) $from => "{$what}: from " . $this->day($from),
            (bool) $to   => "{$what}: up to " . $this->day($to),
            default      => 'All records',
        };
        $by = auth()->user()?->name;
        $summary = $period . '. '
            . number_format($count) . ' ' . ($count === 1 ? 'row' : 'rows') . '. Generated '
            . now()->timezone('Asia/Manila')->format('M j, Y g:i A') . ($by ? " by {$by}" : '') . '.';

        $head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            . '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>'
            . '<sheetViews><sheetView workbookViewId="0">'
            . '<pane ySplit="' . self::HEADER_ROW . '" topLeftCell="A' . (self::HEADER_ROW + 1) . '" activePane="bottomLeft" state="frozen"/>'
            . '</sheetView></sheetViews>'
            . '<sheetFormatPr defaultRowHeight="15"/>'
            . '<cols>' . implode('', array_map(
                fn ($w, $i) => '<col min="' . ($i + 1) . '" max="' . ($i + 1) . '" width="' . min(max($w + 3, 10), 60) . '" customWidth="1"/>',
                $widths, array_keys($widths),
            )) . '</cols>'
            . '<sheetData>'
            . '<row r="1" ht="22" customHeight="1">' . $this->text('A1', $title, 1) . '</row>'
            . '<row r="2">' . $this->text('A2', $summary, 2) . '</row>'
            . '<row r="' . self::HEADER_ROW . '">' . implode('', array_map(
                // A number column's header sits over its numbers, on the right.
                fn ($h, $i) => $this->text($this->column($i + 1) . self::HEADER_ROW, $h,
                    in_array($types[$i], ['int', 'decimal', 'money'], true) ? 9 : 3),
                $headers, array_keys($headers),
            )) . '</row>';

        $tail = '</sheetData>'
            . '<autoFilter ref="A' . self::HEADER_ROW . ':' . $last . '"/>'
            . '<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>'
            . '<pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>'
            . '</worksheet>';

        $sheetName = $this->sheetName($title);
        $quoted = "'" . str_replace("'", "''", $sheetName) . "'";

        $zip = new class {
            private array $entries = [];
            private int $offset = 0;

            /** @param  array<int, string|resource>  $parts */
            public function add(string $name, array $parts): void
            {
                $crc = hash_init('crc32b');
                $size = 0;
                foreach ($parts as $part) {
                    if (is_string($part)) {
                        hash_update($crc, $part);
                        $size += strlen($part);
                    } else {
                        rewind($part);
                        $size += hash_update_stream($crc, $part);
                    }
                }
                $crc = hexdec(hash_final($crc));

                // The same moment for every entry; a zip stores DOS time.
                $time = (now()->hour << 11) | (now()->minute << 5) | intdiv(now()->second, 2);
                $date = ((now()->year - 1980) << 9) | (now()->month << 5) | now()->day;
                $fixed = pack('vvvvvVVVv', 20, 0, 0, $time, $date, $crc, $size, $size, strlen($name));

                echo pack('V', 0x04034b50), $fixed, pack('v', 0), $name;
                foreach ($parts as $part) {
                    if (is_string($part)) {
                        echo $part;
                    } else {
                        rewind($part);
                        fpassthru($part);
                    }
                }

                $this->entries[] = pack('V', 0x02014b50) . pack('v', 20) . $fixed
                    . pack('vvvvVV', 0, 0, 0, 0, 0, $this->offset) . $name;
                $this->offset += 30 + strlen($name) + $size;
            }

            public function finish(): void
            {
                $directory = implode('', $this->entries);
                echo $directory, pack('VvvvvVVv', 0x06054b50, 0, 0, count($this->entries), count($this->entries),
                    strlen($directory), $this->offset, 0);
            }
        };

        $zip->add('[Content_Types].xml', ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            . '<Default Extension="xml" ContentType="application/xml"/>'
            . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            . '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            . '</Types>']);
        $zip->add('_rels/.rels', ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            . '</Relationships>']);
        $zip->add('xl/workbook.xml', ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            . '<sheets><sheet name="' . $this->escape($sheetName) . '" sheetId="1" r:id="rId1"/></sheets>'
            . '<definedNames>'
            // The filter, and the header row repeated on every printed page.
            . '<definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">' . $this->escape($quoted . '!$A$' . self::HEADER_ROW . ':' . $this->absolute($last)) . '</definedName>'
            . '<definedName name="_xlnm.Print_Titles" localSheetId="0">' . $this->escape($quoted . '!$' . self::HEADER_ROW . ':$' . self::HEADER_ROW) . '</definedName>'
            . '</definedNames>'
            . '</workbook>']);
        $zip->add('xl/_rels/workbook.xml.rels', ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            . '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            . '</Relationships>']);
        $zip->add('xl/styles.xml', [$this->styles()]);
        $zip->add('xl/worksheets/sheet1.xml', [$head, $body, $tail]);
        $zip->finish();

        fclose($body);
    }

    private function row(int $r, array $values, array $types, array &$widths): string
    {
        $cells = '';

        foreach ($values as $i => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            $ref = $this->column($i + 1) . $r;
            $type = $types[$i] ?? 'text';

            if (in_array($type, ['date', 'datetime'], true)) {
                $at = Carbon::parse($value)->timezone('Asia/Manila');
                // Days since 1899-12-30, in Manila time: what Excel calls a date.
                $serial = 25569 + ($at->getTimestamp() + $at->getOffset()) / 86400;
                $cells .= '<c r="' . $ref . '" s="' . self::STYLE[$type] . '"><v>' . round($serial, 6) . '</v></c>';
                $widths[$i] = max($widths[$i], $type === 'date' ? 12 : 20);
            } elseif ($type !== 'text' && is_numeric($value)) {
                $cells .= '<c r="' . $ref . '" s="' . self::STYLE[$type] . '"><v>' . (0 + $value) . '</v></c>';
                $widths[$i] = max($widths[$i], strlen(number_format((float) $value, $type === 'int' ? 0 : 2)) + ($type === 'money' ? 2 : 0));
            } else {
                $cells .= $this->text($ref, (string) $value, 0);
                $widths[$i] = max($widths[$i], mb_strlen((string) $value));
            }
        }

        return '<row r="' . $r . '">' . $cells . '</row>';
    }

    private function text(string $ref, string $value, int $style): string
    {
        return '<c r="' . $ref . '" t="inlineStr"' . ($style ? ' s="' . $style . '"' : '') . '>'
            . '<is><t xml:space="preserve">' . $this->escape($value) . '</t></is></c>';
    }

    private function escape(string $value): string
    {
        // Control characters are not allowed in XML at all; one in a
        // job description would make Excel refuse the whole file.
        $value = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', '', $value);

        return htmlspecialchars($value, ENT_XML1 | ENT_QUOTES, 'UTF-8');
    }

    /** 1 => A, 27 => AA. */
    private function column(int $n): string
    {
        $letters = '';
        while ($n > 0) {
            $n--;
            $letters = chr(65 + $n % 26) . $letters;
            $n = intdiv($n, 26);
        }

        return $letters;
    }

    private function absolute(string $ref): string
    {
        return preg_replace('/^([A-Z]+)(\d+)$/', '\$$1\$$2', $ref);
    }

    private function day(string $date): string
    {
        return Carbon::parse($date)->format('M j, Y');
    }

    /** Excel allows 31 characters and none of []:*?/\ in a sheet name. */
    private function sheetName(string $title): string
    {
        return mb_substr(preg_replace('/[\[\]:*?\/\\\\]/', '', $title), 0, 31);
    }

    /*
        0 plain, 1 title, 2 the line under it, 3 header, 4 date and time,
        5 whole number, 6 one decimal, 7 pesos, 8 date, 9 header over numbers.
        Numbers keep a space on their right, so a figure does not run into
        the words in the next column.
    */
    private function styles(): string
    {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            . '<numFmts count="4">'
            . '<numFmt numFmtId="164" formatCode="mmm d, yyyy h:mm AM/PM"/>'
            . '<numFmt numFmtId="165" formatCode="mmm d, yyyy"/>'
            . '<numFmt numFmtId="166" formatCode="&quot;₱&quot;#,##0.00"/>'
            . '<numFmt numFmtId="167" formatCode="0.0"/>'
            . '</numFmts>'
            . '<fonts count="4">'
            . '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
            . '<font><b/><sz val="14"/><name val="Calibri"/><family val="2"/></font>'
            . '<font><sz val="10"/><color rgb="FF64748B"/><name val="Calibri"/><family val="2"/></font>'
            . '<font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
            . '</fonts>'
            . '<fills count="3">'
            . '<fill><patternFill patternType="none"/></fill>'
            . '<fill><patternFill patternType="gray125"/></fill>'
            . '<fill><patternFill patternType="solid"><fgColor rgb="FFF1F5F9"/><bgColor indexed="64"/></patternFill></fill>'
            . '</fills>'
            . '<borders count="2">'
            . '<border><left/><right/><top/><bottom/><diagonal/></border>'
            . '<border><left/><right/><top/><bottom style="thin"><color rgb="FFCBD5E1"/></bottom><diagonal/></border>'
            . '</borders>'
            . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
            . '<cellXfs count="10">'
            . '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
            . '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
            . '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
            . '<xf numFmtId="0" fontId="3" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
            . '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>'
            . '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="right" indent="1"/></xf>'
            . '<xf numFmtId="167" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="right" indent="1"/></xf>'
            . '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="right" indent="1"/></xf>'
            . '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>'
            . '<xf numFmtId="0" fontId="3" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" indent="1"/></xf>'
            . '</cellXfs>'
            . '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
            . '</styleSheet>';
    }
}
