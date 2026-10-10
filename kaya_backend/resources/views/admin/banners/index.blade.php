@extends('admin.layouts.app')
@section('page-title', 'Home Banners')

@section('content')
<div class="grid grid-cols-3 gap-6">
    <div class="col-span-1 bg-white rounded-xl border border-slate-200 p-6 self-start">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Add a banner</h3>
        <p class="text-xs text-slate-500 mb-4">
            Shown in the carousel under Active on the home screen, taking turns with boosted workers and jobs.
            A wide photo works best, about 1200 by 520.
        </p>

        @if ($errors->any())
            <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
        @endif

        <form method="POST" action="{{ route('admin.banners.store') }}" enctype="multipart/form-data">
            @csrf
            <label class="text-xs text-slate-500">Photo</label>
            <input type="file" name="image" accept="image/jpeg,image/png,image/webp" required
                   class="w-full mt-1 mb-3 text-sm">

            <label class="text-xs text-slate-500">Headline</label>
            <input type="text" name="title" value="{{ old('title') }}" required maxlength="60"
                   placeholder="Need a plumber today?"
                   class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">

            <label class="text-xs text-slate-500">Line under it (optional)</label>
            <input type="text" name="body" value="{{ old('body') }}" maxlength="120"
                   placeholder="Verified workers near you, ready this week."
                   class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">

            <label class="text-xs text-slate-500">Shown to</label>
            <select name="audience" class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="both" @selected(old('audience') === 'both')>Everyone</option>
                <option value="worker" @selected(old('audience') === 'worker')>Workers</option>
                <option value="employer" @selected(old('audience') === 'employer')>Employers</option>
            </select>

            <label class="text-xs text-slate-500">Tapping opens</label>
            <select name="action" class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                @foreach ($actions as $value => $label)
                    <option value="{{ $value }}" @selected(old('action') === $value)>{{ $label }}</option>
                @endforeach
            </select>

            <label class="text-xs text-slate-500">Order (lower shows first)</label>
            <input type="number" name="sort_order" value="{{ old('sort_order', 0) }}" min="0" max="999"
                   class="w-full mt-1 mb-4 px-3 py-2 border border-slate-300 rounded-lg text-sm">

            <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Add banner</button>
        </form>
    </div>

    <div class="col-span-2 space-y-4">
        @forelse ($banners as $banner)
            <div class="bg-white rounded-xl border border-slate-200 overflow-hidden flex {{ $banner->is_active ? '' : 'opacity-60' }}">
                <img src="{{ $banner->imageUrl() }}" alt="" class="w-56 h-28 object-cover flex-shrink-0">
                <div class="p-4 flex-1 min-w-0">
                    <p class="font-semibold text-slate-800 truncate">{{ $banner->title }}</p>
                    @if ($banner->body)
                        <p class="text-sm text-slate-600 truncate">{{ $banner->body }}</p>
                    @endif
                    <p class="text-xs text-slate-400 mt-2">
                        {{ ['both' => 'Everyone', 'worker' => 'Workers', 'employer' => 'Employers'][$banner->audience] ?? 'Everyone' }}
                        · Opens {{ strtolower($actions[$banner->action] ?? 'nothing') }}
                        · Order {{ $banner->sort_order }}
                        · {{ $banner->is_active ? 'Showing' : 'Hidden' }}
                    </p>
                </div>
                <div class="p-4 flex flex-col gap-2 justify-center">
                    <form method="POST" action="{{ route('admin.banners.toggle', $banner) }}">
                        @csrf
                        <button class="w-20 px-3 py-1.5 text-xs font-medium rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50">
                            {{ $banner->is_active ? 'Hide' : 'Show' }}
                        </button>
                    </form>
                    <form method="POST" action="{{ route('admin.banners.destroy', $banner) }}"
                          onsubmit="return confirm('Delete this banner?')">
                        @csrf
                        @method('DELETE')
                        <button class="w-20 px-3 py-1.5 text-xs font-medium rounded-lg border border-red-200 text-red-600 hover:bg-red-50">Delete</button>
                    </form>
                </div>
            </div>
        @empty
            <div class="bg-white rounded-xl border border-slate-200 p-8 text-center">
                <p class="text-sm text-slate-600">No banners yet.</p>
                <p class="text-xs text-slate-400 mt-1">Until there is one, the app shows its built-in sample banners.</p>
            </div>
        @endforelse
    </div>
</div>
@endsection
