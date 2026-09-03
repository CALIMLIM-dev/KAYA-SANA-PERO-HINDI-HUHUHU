<?php

namespace Tests\Feature;

use App\Services\ExperienceTotal;
use Illuminate\Support\Collection;
use Tests\TestCase;

/*
    The arithmetic behind "5+ years" on a public profile.

    An employer can read the dates listed underneath the figure, so a total
    that disagrees with them is not a rounding error - it is the profile
    visibly overstating the one claim being weighed. Overlap is the whole
    difficulty and most of these tests are about it.
*/
class ExperienceTotalTest extends TestCase
{
    private function rows(array $pairs): Collection
    {
        return collect($pairs)->map(fn ($p) => (object) [
            'start_date' => $p[0],
            'end_date'   => $p[1],
            'is_current' => $p[2] ?? false,
        ]);
    }

    private ExperienceTotal $total;

    protected function setUp(): void
    {
        parent::setUp();
        $this->total = new ExperienceTotal();
    }

    public function test_a_single_two_year_job_is_two_years(): void
    {
        $this->assertSame(2, $this->total->years($this->rows([
            ['2020-01-01', '2021-12-31'],
        ])));
    }

    /*
        The reason this class exists.

        Two concurrent jobs across the same two years is two years of
        experience. Summing the rows says four, and the dates on the same
        screen say otherwise.
    */
    public function test_two_concurrent_jobs_count_once(): void
    {
        $this->assertSame(2, $this->total->years($this->rows([
            ['2020-01-01', '2021-12-31'],
            ['2020-01-01', '2021-12-31'],
        ])));
    }

    public function test_partly_overlapping_jobs_merge_into_one_span(): void
    {
        // 2019-01 to 2021-12 is three years, despite four years of rows.
        $this->assertSame(3, $this->total->years($this->rows([
            ['2019-01-01', '2020-06-30'],
            ['2020-01-01', '2021-12-31'],
        ])));
    }

    /*
        A short job inside a long one must not shorten the total.

        Taking the later row's end date blindly would have pulled the span
        back to 2020 and reported one year instead of three.
    */
    public function test_a_job_nested_inside_another_adds_nothing(): void
    {
        $this->assertSame(3, $this->total->years($this->rows([
            ['2019-01-01', '2021-12-31'],
            ['2020-03-01', '2020-05-31'],
        ])));
    }

    public function test_separate_jobs_with_a_gap_are_added(): void
    {
        // Two years, a fallow year, then two more.
        $this->assertSame(4, $this->total->years($this->rows([
            ['2016-01-01', '2017-12-31'],
            ['2019-01-01', '2020-12-31'],
        ])));
    }

    public function test_a_current_job_counts_up_to_today(): void
    {
        $start = now()->subYears(3)->format('Y-m-d');

        $this->assertSame(3, $this->total->years($this->rows([
            [$start, null, true],
        ])));
    }

    /*
        A new worker is not labelled with a zero.

        This app deliberately welcomes workers with no formal written history,
        and "0 years" on their profile reads as a mark against them rather than
        as an empty field.
    */
    public function test_less_than_a_year_has_no_label(): void
    {
        $this->assertNull($this->total->label($this->rows([
            ['2024-01-01', '2024-04-30'],
        ])));
    }

    public function test_no_experience_at_all_is_zero_and_unlabelled(): void
    {
        $this->assertSame(0, $this->total->years(collect()));
        $this->assertNull($this->total->label(collect()));
    }

    public function test_one_year_is_singular(): void
    {
        $this->assertSame('1 year', $this->total->label($this->rows([
            ['2020-01-01', '2020-12-31'],
        ])));
    }

    public function test_more_than_one_year_is_plural_and_open_ended(): void
    {
        $this->assertSame('5+ years', $this->total->label($this->rows([
            ['2016-01-01', '2020-12-31'],
        ])));
    }

    /*
        Bad data must not produce a bigger number than good data.

        A row with no end date and no current flag used to be the tempting
        place to assume "still going", which would silently inflate every
        total containing one.
    */
    public function test_an_open_row_that_is_not_current_does_not_run_forever(): void
    {
        $this->assertSame(0, $this->total->years($this->rows([
            ['2015-01-01', null, false],
        ])));
    }

    public function test_an_end_date_before_the_start_does_not_go_negative(): void
    {
        $this->assertSame(1, $this->total->years($this->rows([
            ['2020-01-01', '2019-01-01'],
            ['2021-01-01', '2021-12-31'],
        ])));
    }

    public function test_a_row_with_no_start_date_is_ignored(): void
    {
        $this->assertSame(1, $this->total->years($this->rows([
            [null, '2021-12-31'],
            ['2020-01-01', '2020-12-31'],
        ])));
    }

    /*
        Order of entry must not change the answer.

        Rows arrive in whatever order they were typed, and merging depends on
        them being sorted first.
    */
    public function test_the_result_does_not_depend_on_row_order(): void
    {
        $forwards = $this->rows([
            ['2016-01-01', '2017-12-31'],
            ['2019-01-01', '2020-12-31'],
        ]);
        $backwards = $this->rows([
            ['2019-01-01', '2020-12-31'],
            ['2016-01-01', '2017-12-31'],
        ]);

        $this->assertSame(
            $this->total->months($forwards),
            $this->total->months($backwards)
        );
    }
}
