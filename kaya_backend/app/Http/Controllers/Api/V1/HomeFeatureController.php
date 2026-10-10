<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Banner;
use App\Models\Boost;
use App\Models\JobPost;
use App\Models\WorkerProfile;
use Illuminate\Http\Request;

/*
    What the home carousel shows: the admin's banners, and boosted profiles
    as ads.

    A boost already bought a place at the top of a list; this gives it a
    second, more visible one. A worker side sees boosted jobs and an
    employer side boosted workers - each the thing that side is looking
    for. A user's own photo is not the ad: the app draws the ad over a
    stock photo of their trade and shows the photo small, as an avatar,
    so a selfie never has to fill a banner.
*/
class HomeFeatureController extends Controller
{
    private const ADS = 4;

    public function index(Request $request)
    {
        $data = $request->validate(['side' => ['required', 'in:worker,employer']]);
        $side = $data['side'];
        $viewer = $request->user();

        $banners = Banner::shownTo($side)->take(6)->get()->map(fn (Banner $b) => [
            'kind'      => 'banner',
            'id'        => $b->id,
            'title'     => $b->title,
            'body'      => $b->body,
            'image_url' => $b->imageUrl(),
            'action'    => $b->action,
        ]);

        $ads = $side === 'employer' ? $this->workerAds($viewer->id) : $this->jobAds($viewer->id);

        return response()->json([
            'success' => true,
            'data'    => ['banners' => $banners->values(), 'ads' => $ads->values()],
        ]);
    }

    private function boosted(string $type)
    {
        return Boost::query()->active()
            ->where('boostable_type', $type)
            ->latest('starts_at')
            ->pluck('boostable_id')
            ->unique();
    }

    private function workerAds(int $viewerId)
    {
        $ids = $this->boosted(Boost::TYPE_WORKER);

        return WorkerProfile::with(['user:id,name,avatar,is_verified', 'category:id,name', 'skills'])
            ->whereIn('user_id', $ids)
            ->where('user_id', '!=', $viewerId)
            ->get()
            ->filter(fn (WorkerProfile $p) => $p->isListable())
            ->take(self::ADS)
            ->map(fn (WorkerProfile $p) => [
                'kind'         => 'worker',
                'user_id'      => $p->user_id,
                'name'         => $p->user?->name,
                'avatar'       => $p->resolvedAvatarUrl(),
                'category'     => $p->category?->name,
                'location'     => $p->location,
                'rating_avg'   => $p->rating_count > 0 ? (float) $p->rating_avg : null,
                'rating_count' => (int) $p->rating_count,
                'rate_label'   => $p->rateLabel(),
                'verification_state' => $p->user?->verification_state ?? 'unverified',
            ]);
    }

    private function jobAds(int $viewerId)
    {
        $ids = $this->boosted(Boost::TYPE_JOB);

        return JobPost::with('category:id,name')
            ->live()
            ->whereIn('id', $ids)
            ->where('employer_id', '!=', $viewerId)
            ->take(self::ADS)
            ->get()
            ->map(fn (JobPost $j) => [
                'kind'          => 'job',
                'id'            => $j->id,
                'title'         => $j->title,
                'category'      => $j->category?->name,
                'location'      => $j->city ?: $j->location,
                'budget_min'    => $j->budget_min === null ? null : (float) $j->budget_min,
                'budget_max'    => $j->budget_max === null ? null : (float) $j->budget_max,
                'budget_period' => $j->budget_period,
            ]);
    }
}
