@extends('admin.layouts.app')
@section('page-title', 'Reviews')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <div class="flex gap-1">
            @foreach (['visible' => 'Live', 'hidden' => 'Hidden', 'all' => 'All'] as $key => $label)
                <a href="{{ route('admin.reviews.index', array_filter(['show' => $key, 'search' => $search, 'rating' => $rating ?: null])) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                    {{ $label }}
                    @if ($key !== 'all')<span class="text-xs text-slate-400">{{ $counts[$key] }}</span>@endif
                </a>
            @endforeach
        </div>
        <form method="GET" class="flex items-center gap-2 ml-auto">
            <input type="hidden" name="show" value="{{ $show }}">
            <input type="text" name="search" value="{{ $search }}" placeholder="Name or words in the review"
                   class="w-64 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <select name="rating" class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="">Any stars</option>
                @for ($i = 1; $i <= 5; $i++)
                    <option value="{{ $i }}" @selected($rating === $i)>{{ $i }} star{{ $i > 1 ? 's' : '' }}</option>
                @endfor
            </select>
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Filter</button>
        </form>
    </div>

    <div class="divide-y divide-slate-50">
        @forelse ($reviews as $review)
            <div class="p-5 flex gap-5 {{ $review->isHidden() ? 'bg-slate-50' : '' }}">
                <div class="w-14 flex-shrink-0 text-center">
                    <p class="text-2xl font-bold text-slate-800">{{ $review->rating }}</p>
                    <p class="text-xs text-slate-400">of 5</p>
                </div>
                <div class="flex-1 min-w-0">
                    <p class="text-sm text-slate-500">
                        @if ($review->reviewer)
                            <a href="{{ route('admin.users.show', $review->reviewer) }}" class="text-slate-700 font-medium hover:text-blue-600">{{ $review->reviewer->name }}</a>
                        @else <span class="text-slate-400">Deleted account</span> @endif
                        about
                        @if ($review->reviewee)
                            <a href="{{ route('admin.users.show', $review->reviewee) }}" class="text-slate-700 font-medium hover:text-blue-600">{{ $review->reviewee->name }}</a>
                        @else <span class="text-slate-400">a deleted account</span> @endif
                        as {{ $review->reviewee_role }}
                        @if ($review->job)
                            on <a href="{{ route('admin.jobs.show', $review->job) }}" class="text-blue-600">{{ $review->job->title }}</a>
                        @endif
                        <span class="text-slate-400">&middot; {{ $review->created_at->format('M j, Y') }}</span>
                    </p>
                    <p class="text-sm text-slate-800 mt-1.5 whitespace-pre-line">{{ $review->comment ?: 'No comment, stars only.' }}</p>
                    @if ($review->tags)
                        <div class="flex flex-wrap gap-1.5 mt-2">
                            @foreach ($review->tags as $tag)
                                <span class="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">{{ $tag }}</span>
                            @endforeach
                        </div>
                    @endif
                    @if ($review->isHidden())
                        <p class="text-xs text-red-600 mt-2">
                            Hidden {{ $review->hidden_at->format('M j, Y') }} by {{ $review->hider?->name ?? 'admin' }}: {{ $review->hidden_reason }}
                        </p>
                    @endif
                </div>
                <div class="w-56 flex-shrink-0">
                    @if ($review->isHidden())
                        <form method="POST" action="{{ route('admin.reviews.restore', $review->id) }}">
                            @csrf
                            <button class="w-full px-3 py-2 border border-slate-300 text-slate-700 rounded-lg text-sm hover:bg-white">Restore</button>
                        </form>
                    @else
                        <form method="POST" action="{{ route('admin.reviews.hide', $review->id) }}" onsubmit="return confirm('Hide this review?')">
                            @csrf
                            <input type="text" name="reason" required maxlength="255" placeholder="Reason"
                                   class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
                            <button class="w-full px-3 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm hover:bg-red-100">Hide review</button>
                        </form>
                    @endif
                </div>
            </div>
        @empty
            <p class="p-8 text-center text-slate-400 text-sm">No reviews match.</p>
        @endforelse
    </div>

    <div class="p-5">{{ $reviews->links() }}</div>
</div>
@endsection
