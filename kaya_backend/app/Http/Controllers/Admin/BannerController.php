<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Banner;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

/*
    The photo banners under Active on the home screen.

    A photo, a headline, a line under it and where a tap goes. Changing one
    needs no app update: the app reads them every time home loads. Boosted
    workers and jobs take turns with these in the same carousel and are not
    managed here - they come from boosts.
*/
class BannerController extends Controller
{
    public function index()
    {
        $banners = Banner::orderByDesc('is_active')->orderBy('sort_order')->latest('id')->get();

        return view('admin.banners.index', [
            'banners' => $banners,
            'actions' => Banner::ACTIONS,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            // Optional: a designed banner carries its words in the photo.
            'title'      => ['nullable', 'string', 'max:60'],
            'body'       => ['nullable', 'string', 'max:120'],
            'image'      => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
            'audience'   => ['required', Rule::in(Banner::AUDIENCES)],
            'action'     => ['required', Rule::in(array_keys(Banner::ACTIONS))],
            'sort_order' => ['nullable', 'integer', 'min:0', 'max:999'],
        ], [
            'image.required' => 'Choose a photo for the banner.',
            'image.max'      => 'The photo must be 4 MB or smaller.',
        ]);

        $path = $request->file('image')->store('banners', config('filesystems.media'));

        $banner = Banner::create([
            'title'      => filled($data['title'] ?? null) ? trim($data['title']) : null,
            'body'       => $data['body'] ?? null,
            'image_path' => $path,
            'audience'   => $data['audience'],
            'action'     => $data['action'],
            'sort_order' => $data['sort_order'] ?? 0,
            'created_by' => Auth::id(),
        ]);

        AdminAction::record('banner.created', 'banner', $banner->id, 'Added the banner ' . $banner->label());

        return back()->with('success', 'Banner added. It shows on home the next time the app loads it.');
    }

    public function toggle(Banner $banner)
    {
        $banner->update(['is_active' => ! $banner->is_active]);

        AdminAction::record(
            $banner->is_active ? 'banner.shown' : 'banner.hidden', 'banner', $banner->id,
            ($banner->is_active ? 'Showed' : 'Hid') . ' the banner ' . $banner->label(),
        );

        return back()->with('success', $banner->is_active ? 'Banner is showing.' : 'Banner is hidden.');
    }

    public function destroy(Banner $banner)
    {
        Storage::disk(config('filesystems.media'))->delete($banner->image_path);
        AdminAction::record('banner.deleted', 'banner', $banner->id, 'Deleted the banner ' . $banner->label());
        $banner->delete();

        return back()->with('success', 'Banner deleted.');
    }
}
