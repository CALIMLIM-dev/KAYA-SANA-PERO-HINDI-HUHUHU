<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Supply and demand by place: what is lacking where, for any place, with a
    map that never shows anybody's own pin.
*/
class SupplyDemandTest extends TestCase
{
    use RefreshDatabase;

    private Location $province;
    private Location $urdaneta;
    private Location $lingayen;
    private Category $plumbing;

    protected function setUp(): void
    {
        parent::setUp();

        $n = 0;
        $loc = function (string $name, string $type, ?int $parent, ?float $lat = null, ?float $lng = null) use (&$n) {
            $n++;
            return Location::forceCreate(['psgc_code' => (string) (100000 + $n), 'name' => $name, 'type' => $type,
                'parent_id' => $parent, 'latitude' => $lat, 'longitude' => $lng]);
        };
        $region = $loc('Region I', 'region', null, 16.08, 120.62);
        $this->province = $loc('Pangasinan', 'province', $region->id, 15.90, 120.33);
        // About 35 km apart: well outside each other's 10 km reach.
        $this->urdaneta = $loc('Urdaneta City', 'city', $this->province->id, 15.9761, 120.5711);
        $this->lingayen = $loc('Lingayen', 'municipality', $this->province->id, 16.0218, 120.2319);
        $this->plumbing = Category::create(['name' => 'Plumbing']);
    }

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    private function worker(Location $at, array $extra = []): User
    {
        $u = User::factory()->create(['name' => 'Ramon Aquino']);
        WorkerProfile::create(array_merge(['user_id' => $u->id, 'category_id' => $this->plumbing->id, 'location' => 'x', 'location_id' => $at->id], $extra));

        return $u;
    }

    private function job(Location $at, string $status = 'open'): JobPost
    {
        $e = User::factory()->create();
        EmployerProfile::create(['user_id' => $e->id, 'location_id' => $at->id]);

        return JobPost::create(['employer_id' => $e->id, 'category_id' => $this->plumbing->id, 'title' => 'Fix pipes',
            'description' => 'x', 'location' => 'x', 'location_id' => $at->id, 'status' => $status]);
    }

    #[Test]
    public function the_ranking_puts_the_town_whose_jobs_outrun_its_workers_first(): void
    {
        // Urdaneta: three jobs, nobody in reach. Lingayen: one job, two workers.
        foreach (range(1, 3) as $_) {
            $this->job($this->urdaneta);
        }
        $this->job($this->lingayen);
        $this->worker($this->lingayen);
        $this->worker($this->lingayen);

        $ranking = $this->actingAs($this->admin())->get('/admin/supply-demand')->assertOk()->viewData('ranking');

        $this->assertSame('Urdaneta City', $ranking[0]['name']);
        $this->assertSame(3, $ranking[0]['jobs']);
        $this->assertSame(0, $ranking[0]['workers']);
        $this->assertSame(3, $ranking[0]['gap']);
        $this->assertSame('Plumbing', $ranking[0]['short']);

        $this->assertSame('Lingayen', $ranking[1]['name']);
        $this->assertSame(-1, $ranking[1]['gap'], 'one spare');
    }

    #[Test]
    public function a_town_counts_the_workers_in_reach_not_only_those_living_there(): void
    {
        // A barangay with no coordinates of its own sits at its town's centre.
        $barangay = Location::forceCreate(['psgc_code' => '999001', 'name' => 'Nancayasan', 'type' => 'barangay', 'parent_id' => $this->urdaneta->id]);
        $this->job($barangay);
        $this->worker($barangay);

        $response = $this->actingAs($this->admin())->get('/admin/supply-demand?place=' . $this->urdaneta->id)->assertOk();
        $summary = $response->viewData('summary');

        $this->assertSame(1, $summary['jobs']);
        $this->assertSame(1, $summary['workers']);
        $this->assertTrue($summary['reach']);
        $response->assertSee('Workers in Reach')->assertSee('Pangasinan')->assertSee('Region I');

        // The job sitting in a barangay is named with its town.
        $response->assertSee('Nancayasan, Urdaneta City');
    }

    #[Test]
    public function a_province_counts_everything_inside_it_however_deep(): void
    {
        $barangay = Location::forceCreate(['psgc_code' => '999002', 'name' => 'Poblacion', 'type' => 'barangay', 'parent_id' => $this->lingayen->id]);
        $this->job($barangay);
        $this->job($this->urdaneta);
        $this->worker($barangay);

        $summary = $this->actingAs($this->admin())->get('/admin/supply-demand?place=' . $this->province->id)->viewData('summary');

        $this->assertSame(2, $summary['jobs']);
        $this->assertSame(1, $summary['workers']);
        $this->assertFalse($summary['reach'], 'a province counts its residents');
    }

    #[Test]
    public function the_map_shows_towns_and_counts_never_a_person(): void
    {
        // A worker who dropped an exact pin on their house.
        $this->worker($this->urdaneta, ['latitude' => 15.98123, 'longitude' => 120.57456]);

        $response = $this->actingAs($this->admin())->get('/admin/supply-demand');
        $map = $response->viewData('map');

        $this->assertSame(['towns', 'focus'], array_keys($map));
        $town = $map['towns'][0];
        $this->assertSame('Urdaneta City', $town['name']);
        $this->assertSame(1, $town['residents']);
        // At the town's centre, not the house.
        $this->assertEqualsWithDelta(15.9761, $town['lat'], 0.00001);

        // Neither the pin nor the person reaches the page.
        $response->assertDontSee('15.98123')->assertDontSee('Ramon Aquino');
    }

    #[Test]
    public function places_can_be_searched_and_a_trade_narrows_everything(): void
    {
        $other = Category::create(['name' => 'Electrical']);
        $this->job($this->urdaneta);
        JobPost::create(['employer_id' => User::factory()->create()->id, 'category_id' => $other->id, 'title' => 'Rewire',
            'description' => 'x', 'location' => 'x', 'location_id' => $this->urdaneta->id, 'status' => 'open']);

        $admin = $this->admin();
        $this->actingAs($admin)->get('/admin/supply-demand?q=urdan')->assertOk()->assertSee('Urdaneta City');

        $summary = $this->actingAs($admin)->get('/admin/supply-demand?trade=' . $other->id)->viewData('summary');
        $this->assertSame(1, $summary['jobs']);
        $this->assertSame('Electrical', $summary['trades'][0]['name']);
    }

    #[Test]
    public function the_shortage_table_downloads_as_a_workbook(): void
    {
        foreach (range(1, 3) as $_) {
            $this->job($this->urdaneta);
        }
        $this->worker($this->lingayen);

        $response = $this->actingAs($this->admin())->get('/admin/supply-demand/export?days=30')->assertOk();
        $this->assertStringContainsString('.xlsx', $response->headers->get('Content-Disposition'));

        ob_start();
        $response->baseResponse->sendContent();
        $path = tempnam(sys_get_temp_dir(), 'xlsx');
        file_put_contents($path, ob_get_clean());

        $zip = new \ZipArchive();
        $this->assertTrue($zip->open($path) === true);
        $sheet = $zip->getFromName('xl/worksheets/sheet1.xml');
        $zip->close();
        unlink($path);

        $this->assertStringContainsString('Supply and Demand by Place', $sheet);
        $this->assertStringContainsString('Urdaneta City', $sheet);
        $this->assertStringContainsString('Short By', $sheet);
    }

    #[Test]
    public function it_is_an_admin_page(): void
    {
        $this->actingAs(User::factory()->create())->get('/admin/supply-demand')->assertRedirect();
        $this->actingAs($this->admin())->get('/admin')->assertSee('Workers &amp; Jobs', false);
    }
}
