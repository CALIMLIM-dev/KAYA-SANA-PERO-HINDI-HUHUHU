@extends('admin.layouts.app')
@section('page-title', 'Home Banners')

@section('content')
<div class="grid grid-cols-3 gap-6">
    <div class="col-span-1 bg-white rounded-xl border border-slate-200 p-6 self-start">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Add a banner</h3>
        <p class="text-xs text-slate-500 mb-4">
            Shown in the carousel at the top of the home screen, taking turns with boosted workers and jobs.
            A wide photo works best, about 1200 by 520. If your design already has its words in it, leave the
            headline empty and the photo shows exactly as you made it.
        </p>

        @if ($errors->any())
            <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
        @endif

        <form method="POST" action="{{ route('admin.banners.store') }}" enctype="multipart/form-data" id="banner-form">
            @csrf
            <label class="text-xs text-slate-500">Photo</label>
            <input type="file" name="image" id="banner-image" accept="image/jpeg,image/png,image/webp" required
                   class="w-full mt-1 mb-2 text-sm">

            {{-- The crop the app uses, so what is cut off shows here first. --}}
            <div id="banner-preview" class="hidden mb-1 rounded-xl overflow-hidden border border-slate-200" style="aspect-ratio: 2.3 / 1">
                <img alt="" class="w-full h-full object-cover">
            </div>
            <p id="banner-note" class="hidden text-xs text-slate-500 mb-3"></p>

            <label class="text-xs text-slate-500">Headline (optional)</label>
            <input type="text" name="title" value="{{ old('title') }}" maxlength="60"
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

            <button id="banner-submit" class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Add banner</button>
        </form>
    </div>

    <div class="col-span-2 space-y-4">
        @forelse ($banners as $banner)
            <div class="bg-white rounded-xl border border-slate-200 overflow-hidden flex {{ $banner->is_active ? '' : 'opacity-60' }}">
                <img src="{{ $banner->imageUrl() }}" alt="" class="w-56 h-28 object-cover flex-shrink-0">
                <div class="p-4 flex-1 min-w-0">
                    <p class="font-semibold text-slate-800 truncate">{{ $banner->title ?: 'Photo only' }}</p>
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

@push('scripts')
<script>
/*
    Shrunk in the browser before it is sent.

    The server takes at most 1 MB in one request, and a phone photo or an
    exported design is often several times that - nginx refused it with
    "413 Request Entity Too Large" before KAYA ever saw it. The app shows a
    banner at most about 1200 pixels wide, so the photo is scaled to 1600 and
    saved as a JPEG, stepping the quality down only until it fits. A photo
    that is already small enough is sent untouched.
*/
(function () {
    const form = document.getElementById('banner-form');
    const input = document.getElementById('banner-image');
    const preview = document.getElementById('banner-preview');
    const note = document.getElementById('banner-note');
    const submit = document.getElementById('banner-submit');
    const LIMIT = 900 * 1024;
    const MAX_W = 1600;
    let ready = null;

    function kb(n) { return Math.round(n / 1024) + ' KB'; }

    function load(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = reject;
            img.src = URL.createObjectURL(file);
        });
    }

    async function shrink(file) {
        const img = await load(file);
        if (file.size <= LIMIT && img.naturalWidth <= MAX_W) return file;

        const scale = Math.min(1, MAX_W / img.naturalWidth);
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(img.naturalWidth * scale);
        canvas.height = Math.round(img.naturalHeight * scale);
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';           // a transparent PNG has no black behind it
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

        for (const quality of [0.92, 0.85, 0.78, 0.7, 0.62]) {
            const blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', quality));
            if (blob && blob.size <= LIMIT) {
                return new File([blob], file.name.replace(/\.\w+$/, '') + '.jpg', { type: 'image/jpeg' });
            }
        }
        return null;
    }

    input.addEventListener('change', async () => {
        const file = input.files[0];
        ready = null;
        if (!file) { preview.classList.add('hidden'); note.classList.add('hidden'); return; }

        preview.querySelector('img').src = URL.createObjectURL(file);
        preview.classList.remove('hidden');
        note.classList.remove('hidden');
        note.textContent = 'Preparing the photo...';
        submit.disabled = true;

        try {
            ready = await shrink(file);
            note.textContent = ready === null
                ? 'This photo is too large even after shrinking. Try a smaller one.'
                : (ready === file
                    ? 'Shown in the app cropped like this. ' + kb(file.size) + '.'
                    : 'Shown in the app cropped like this. Shrunk from ' + kb(file.size) + ' to ' + kb(ready.size) + ' to fit the upload limit.');
        } catch (e) {
            ready = file;
            note.textContent = 'Shown in the app cropped like this.';
        }
        submit.disabled = ready === null;
    });

    form.addEventListener('submit', (event) => {
        if (!ready || ready === input.files[0]) return;
        // Swap in the shrunk photo before the form goes.
        const dt = new DataTransfer();
        dt.items.add(ready);
        input.files = dt.files;
    });
})();
</script>
@endpush