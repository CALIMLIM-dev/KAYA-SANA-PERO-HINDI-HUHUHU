<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\WorkerProfile;
use App\Services\JobMatchService;
use App\Services\WorkingDistance;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/*
    Supply and demand by place: what is lacking where.

    The panel can open any place - a region, a province, a town, a barangay -
    and see the jobs posted there against the workers who can take them. A
    ranking of every town does the looking for them, so nobody has to open
    places one by one to find the short ones.

    Demand is the jobs posted in the period. Supply is the workers within
    reach: the 10 km a worker may apply across (WorkingDistance), measured
    from the town's centre. Counting only workers who live inside a place
    would call a barangay empty while its neighbours are full of plumbers.

    The map shows towns and counts, never a person. An individual pin - even
    at barangay level - was close enough to somebody's house to be
    uncomfortable on a screen shown to a panel, and a name with a profile
    link on a map invites browsing people by where they live. Who exactly is
    in a town is one click away in Users, where that belongs.
*/
class SupplyDemandController extends Controller
{
    private const HIRED = ['accepted', 'completed', 'unsuccessful'];

    private const TOWN_TYPES = [Location::TYPE_CITY, Location::TYPE_MUNICIPALITY];

    public function index(Request $request)
    {
        $days = (int) $request->query('days', 30);
        $days = in_array($days, [7, 30, 90], true) ? $days : 30;
        $from = Carbon::now()->subDays($days - 1)->startOfDay();
        $to = Carbon::now()->addDay()->startOfDay();

        $tradeId = (int) $request->query('trade') ?: null;
        $place = $request->filled('place') ? Location::with('parent.parent.parent')->find((int) $request->query('place')) : null;
        $q = trim((string) $request->query('q', ''));

        $workers = $this->workers($tradeId);
        $employers = $this->employers();
        $jobs = $this->jobs($tradeId, $from, $to);

        $towns = $this->towns($workers, $employers, $jobs);

        // The ranking: towns inside the chosen place, most short first.
        $inPlace = $place ? array_flip($this->descendants($place)) : null;
        $ranking = collect($towns)
            ->filter(fn ($t) => $t['jobs'] > 0 && ($inPlace === null || isset($inPlace[$t['id']])))
            ->sortBy([['gap', 'desc'], ['jobs', 'desc']])
            ->values()
            ->all();

        return view('admin.supply.index', [
            'days'      => $days,
            'trades'    => Category::where('is_active', true)->orderBy('name')->get(['id', 'name']),
            'tradeId'   => $tradeId,
            'place'     => $place,
            'trail'     => $place ? $this->trail($place) : [],
            'q'         => $q,
            'matches'   => $q === '' ? collect() : $this->search($q),
            'summary'   => $this->summary($place, $workers, $employers, $jobs),
            'ranking'   => $ranking,
            'map'       => [
                // Towns only: names and counts, no people.
                'towns'     => array_values(array_filter($towns, fn ($t) => $t['lat'] !== null)),
                'focus'     => $place ? $this->focus($place) : null,
            ],
        ]);
    }

    // ── Who and what, and where ──────────────────────────────────────────────

    /** @return Collection<int, array> */
    private function workers(?int $tradeId): Collection
    {
        return WorkerProfile::query()
            ->with(['user:id,deleted_at', 'category:id,name', 'psgcLocation.parent.parent'])
            ->whereNotNull('category_id')
            ->when($tradeId, fn ($w) => $w->where('category_id', $tradeId))
            ->get()
            ->filter(fn ($p) => $p->user && ! $p->user->deleted_at)
            ->map(function (WorkerProfile $p) {
                [$lat, $lng] = $this->spot($p->psgcLocation, $p->latitude, $p->longitude);

                return [
                    'user_id'  => $p->user_id,
                    'trade_id' => $p->category_id,
                    'trade'    => $p->category?->name,
                    'loc'      => $p->psgcLocation,
                    // Where they measure reach from; never drawn.
                    'lat'      => $lat,
                    'lng'      => $lng,
                ];
            })
            ->values();
    }

    /** @return Collection<int, array> */
    private function employers(): Collection
    {
        $profiles = EmployerProfile::with('user:id,deleted_at')->get()
            ->filter(fn ($p) => $p->user && ! $p->user->deleted_at);
        $places = Location::with('parent.parent')->whereIn('id', $profiles->pluck('location_id')->filter())->get()->keyBy('id');

        return $profiles->map(fn (EmployerProfile $p) => ['loc' => $places[$p->location_id] ?? null])->values();
    }

    /** Jobs posted in the period, with whether anybody was hired. */
    private function jobs(?int $tradeId, Carbon $from, Carbon $to): Collection
    {
        return JobPost::query()
            ->with(['category:id,name', 'psgcLocation.parent.parent'])
            ->withCount('applications')
            ->withExists(['applications as hired' => fn ($a) => $a->whereIn('status', self::HIRED)])
            ->where('created_at', '>=', $from)->where('created_at', '<', $to)
            ->when($tradeId, fn ($j) => $j->where('category_id', $tradeId))
            ->get()
            ->map(function (JobPost $j) {
                $unfilled = $j->status === 'open' && ! $j->hired;

                return [
                    'id'         => $j->id,
                    'title'      => $j->title,
                    'trade_id'   => $j->category_id,
                    'trade'      => $j->category?->name,
                    'loc'        => $j->psgcLocation,
                    'unfilled'   => $unfilled,
                    'applicants' => (int) $j->applications_count,
                    'posted'     => $j->created_at,
                ];
            })
            ->values();
    }

    /*
        Where a worker is measured from for reach: their barangay or town,
        or their own pin when they have no place on file. Only used to count;
        nothing here is drawn.
    */
    private function spot(?Location $loc, $lat, $lng): array
    {
        if ($loc) {
            [$a, $b] = $loc->centroid();
            if ($a !== null) {
                return [$a, $b];
            }
        }

        return $lat !== null && $lng !== null ? [round((float) $lat, 2), round((float) $lng, 2)] : [null, null];
    }

    /** The town a place belongs to: itself, or a barangay's town. */
    private function town(?Location $loc): ?Location
    {
        if ($loc?->type === Location::TYPE_BARANGAY) {
            $loc = $loc->parent;
        }

        return $loc && in_array($loc->type, self::TOWN_TYPES, true) ? $loc : null;
    }

    // ── Towns ────────────────────────────────────────────────────────────────

    /*
        Every town with a job, an employer or a worker in it, and how its
        demand compares with the workers in reach.

        ponytail: workers are measured against every town in PHP, towns x
        workers. Fine for a few thousand profiles; past that, bucket workers
        by town first or move the distance into SQL.
    */
    private function towns(Collection $workers, Collection $employers, Collection $jobs): array
    {
        $towns = [];
        $touch = function (?Location $t) use (&$towns) {
            if (! $t) {
                return null;
            }
            [$lat, $lng] = $t->centroid();
            $towns[$t->id] ??= [
                'id' => $t->id, 'name' => $t->name, 'province' => $t->parent?->name,
                'lat' => $lat, 'lng' => $lng,
                'jobs' => 0, 'unfilled' => 0, 'employers' => 0, 'residents' => 0, 'workers' => 0,
                'demand' => [], 'short' => null, 'gap' => 0,
            ];

            return $t->id;
        };

        foreach ($jobs as $j) {
            if ($id = $touch($this->town($j['loc']))) {
                $towns[$id]['jobs']++;
                $towns[$id]['unfilled'] += $j['unfilled'] ? 1 : 0;
                $towns[$id]['demand'][$j['trade'] ?? 'Other'] = ($towns[$id]['demand'][$j['trade'] ?? 'Other'] ?? 0) + 1;
            }
        }
        foreach ($employers as $e) {
            if ($id = $touch($this->town($e['loc']))) {
                $towns[$id]['employers']++;
            }
        }
        foreach ($workers as $w) {
            if ($id = $touch($this->town($w['loc']))) {
                $towns[$id]['residents']++;
            }
        }

        foreach ($towns as &$t) {
            $byTrade = [];
            foreach ($workers as $w) {
                if ($this->inReach($t['lat'], $t['lng'], $w['lat'], $w['lng'])) {
                    $t['workers']++;
                    $byTrade[$w['trade'] ?? 'Other'] = ($byTrade[$w['trade'] ?? 'Other'] ?? 0) + 1;
                }
            }
            $t['gap'] = $t['jobs'] - $t['workers'];

            // The trade furthest behind: most jobs over the workers who do it.
            $worst = null;
            foreach ($t['demand'] as $trade => $n) {
                $gap = $n - ($byTrade[$trade] ?? 0);
                if ($gap > 0 && ($worst === null || $gap > $worst[1])) {
                    $worst = [$trade, $gap];
                }
            }
            $t['short'] = $worst[0] ?? null;
            unset($t['demand']);
        }

        return $towns;
    }

    private function inReach(?float $lat1, ?float $lng1, ?float $lat2, ?float $lng2): bool
    {
        $km = JobMatchService::distanceBetween($lat1, $lng1, $lat2, $lng2);

        return $km !== null && $km <= WorkingDistance::LIMIT_KM;
    }

    // ── One place ────────────────────────────────────────────────────────────

    /*
        The figures for one place, or for everywhere.

        A town or barangay counts the workers in reach of its centre; a
        province or region, too wide for one centre, counts the workers who
        live in it.
    */
    private function summary(?Location $place, Collection $workers, Collection $employers, Collection $jobs): array
    {
        if ($place) {
            $ids = array_flip($this->descendants($place));
            $inside = fn ($loc) => $loc !== null && isset($ids[$loc->id]);
            $jobs = $jobs->filter(fn ($j) => $inside($j['loc']));
            $employers = $employers->filter(fn ($e) => $inside($e['loc']));

            if (in_array($place->type, [...self::TOWN_TYPES, Location::TYPE_BARANGAY], true)) {
                [$lat, $lng] = $place->centroid();
                $workers = $workers->filter(fn ($w) => $this->inReach($lat, $lng, $w['lat'], $w['lng']));
            } else {
                $workers = $workers->filter(fn ($w) => $inside($w['loc']));
            }
        }

        $byTrade = [];
        foreach ($jobs as $j) {
            $byTrade[$j['trade'] ?? 'Other']['jobs'] = ($byTrade[$j['trade'] ?? 'Other']['jobs'] ?? 0) + 1;
        }
        foreach ($workers as $w) {
            $byTrade[$w['trade'] ?? 'Other']['workers'] = ($byTrade[$w['trade'] ?? 'Other']['workers'] ?? 0) + 1;
        }
        $trades = collect($byTrade)
            ->map(fn ($v, $name) => ['name' => $name, 'jobs' => $v['jobs'] ?? 0, 'workers' => $v['workers'] ?? 0])
            ->sortByDesc(fn ($t) => [$t['jobs'] - $t['workers'], $t['jobs']])
            ->values()->all();

        return [
            'jobs'      => $jobs->count(),
            'unfilled'  => $jobs->where('unfilled', true)->count(),
            'workers'   => $workers->count(),
            'employers' => $employers->count(),
            'ratio'     => $workers->count() > 0 ? round($jobs->count() / $workers->count(), 1) : null,
            'trades'    => $trades,
            'skills'    => $this->neededSkills($jobs, $workers),
            'waiting'   => $jobs->where('unfilled', true)->sortBy('posted')->values()->all(),
            // Only a town or barangay is measured by reach; everywhere and a
            // province count everybody in them.
            'reach'     => $place !== null && in_array($place->type, [...self::TOWN_TYPES, Location::TYPE_BARANGAY], true),
        ];
    }

    /** The skills those jobs ask for, against the workers there who list them. */
    private function neededSkills(Collection $jobs, Collection $workers): array
    {
        if ($jobs->isEmpty()) {
            return [];
        }

        $demand = DB::table('job_skills')->join('skills', 'skills.id', '=', 'job_skills.skill_id')
            ->whereIn('job_skills.job_id', $jobs->pluck('id'))
            ->selectRaw('skills.id, skills.name, COUNT(DISTINCT job_skills.job_id) as jobs')
            ->groupBy('skills.id', 'skills.name')
            ->get();

        $supply = DB::table('worker_skills_new')
            ->whereIn('user_id', $workers->pluck('user_id'))
            ->whereIn('skill_id', $demand->pluck('id'))
            ->selectRaw('skill_id, COUNT(DISTINCT user_id) as n')
            ->groupBy('skill_id')
            ->pluck('n', 'skill_id');

        return $demand
            ->map(fn ($s) => ['name' => $s->name, 'jobs' => (int) $s->jobs, 'workers' => (int) ($supply[$s->id] ?? 0)])
            ->sortByDesc(fn ($s) => [$s['jobs'] - $s['workers'], $s['jobs']])
            ->values()->all();
    }

    /** Every place inside this one, itself included, however deep. */
    private function descendants(Location $place): array
    {
        $all = [$place->id];
        $level = [$place->id];
        while ($level !== []) {
            $level = Location::whereIn('parent_id', $level)->pluck('id')->all();
            $all = array_merge($all, $level);
        }

        return $all;
    }

    /** Region > province > town > barangay, down to this place. */
    private function trail(Location $place): array
    {
        $trail = [];
        for ($loc = $place; $loc; $loc = $loc->parent) {
            array_unshift($trail, $loc);
        }

        return $trail;
    }

    private function search(string $q): Collection
    {
        return Location::with('parent.parent')
            ->whereIn('type', [Location::TYPE_REGION, Location::TYPE_PROVINCE, ...self::TOWN_TYPES, Location::TYPE_BARANGAY])
            ->where('name', 'like', '%' . $q . '%')
            ->orderByRaw("CASE type WHEN 'region' THEN 0 WHEN 'province' THEN 1 WHEN 'city' THEN 2 WHEN 'municipality' THEN 2 ELSE 3 END")
            ->orderBy('name')
            ->limit(12)
            ->get();
    }

    /** Where the map opens for a place, and how close. */
    private function focus(Location $place): ?array
    {
        [$lat, $lng] = $place->centroid();
        if ($lat === null) {
            return null;
        }

        $zoom = match ($place->type) {
            Location::TYPE_REGION => 8,
            Location::TYPE_PROVINCE => 9,
            Location::TYPE_BARANGAY => 14,
            default => 12,
        };

        return ['lat' => $lat, 'lng' => $lng, 'zoom' => $zoom];
    }
}
