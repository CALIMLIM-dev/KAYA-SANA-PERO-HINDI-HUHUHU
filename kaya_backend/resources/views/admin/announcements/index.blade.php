@extends('admin.layouts.app')
@section('page-title', 'Announcements')

@section('content')
<div class="grid grid-cols-3 gap-6">
    <div class="col-span-2 bg-white rounded-xl border border-slate-200 p-6">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Send an announcement</h3>
        <p class="text-xs text-slate-500 mb-4">Arrives as a notification in the app. Suspended accounts are skipped. There is no undo, so read it twice.</p>

        @if ($errors->any())
            <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
        @endif

        <form method="POST" action="{{ route('admin.announcements.send') }}" onsubmit="return confirm('Send this to ' + this.audience.options[this.audience.selectedIndex].text.toLowerCase() + '?')">
            @csrf
            <label class="text-xs text-slate-500">Who</label>
            <select name="audience" required class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="both" @selected(old('audience') === 'both')>Everyone ({{ $reach['both'] }} people)</option>
                <option value="worker" @selected(old('audience') === 'worker')>Workers ({{ $reach['worker'] }} people)</option>
                <option value="employer" @selected(old('audience') === 'employer')>Employers ({{ $reach['employer'] }} people)</option>
            </select>

            <label class="text-xs text-slate-500">Title</label>
            <input type="text" name="title" value="{{ old('title') }}" required maxlength="80" placeholder="Short, like a subject line"
                   class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">

            <label class="text-xs text-slate-500">Message</label>
            <textarea name="body" required maxlength="500" rows="4" placeholder="Plain words. Up to 500 characters."
                      class="w-full mt-1 mb-3 px-3 py-2 border border-slate-300 rounded-lg text-sm">{{ old('body') }}</textarea>

            <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Send</button>
        </form>
    </div>

    <div class="bg-white rounded-xl border border-slate-200 p-6">
        <h3 class="text-sm font-semibold text-slate-700 mb-3">Sent before</h3>
        <div class="space-y-3">
            @forelse ($sent as $item)
                <div class="text-sm border-b border-slate-50 pb-3">
                    <p class="font-medium text-slate-800">{{ $item->detail['title'] ?? $item->summary }}</p>
                    <p class="text-slate-600 text-xs mt-0.5">{{ $item->detail['body'] ?? '' }}</p>
                    <p class="text-xs text-slate-400 mt-1">
                        To {{ ['both' => 'everyone', 'worker' => 'workers', 'employer' => 'employers'][$item->detail['audience'] ?? 'both'] ?? 'everyone' }},
                        {{ $item->detail['reached'] ?? 0 }} reached.
                        {{ $item->admin?->name ?? 'Admin' }}, {{ $item->created_at->format('M j, Y') }}
                    </p>
                </div>
            @empty
                <p class="text-sm text-slate-400">Nothing sent yet.</p>
            @endforelse
        </div>
    </div>
</div>
@endsection
