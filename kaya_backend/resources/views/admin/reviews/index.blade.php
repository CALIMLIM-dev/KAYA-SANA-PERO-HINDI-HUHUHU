@extends('admin.layouts.app')
@section('page-title', 'Reviews')

@php
    // The filters the tabs and the form have to carry between them, so
    // switching one does not silently drop the others.
    $carry = array_filter([
        'show'   => $show,
        'role'   => $role !== 'all' ? $role : null,
        'search' => $search,
        'rating' => $rating ?: null,
    ]);
@endphp

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 space-y-3">
        <div class="flex items-center gap-3">
            <div class="flex gap-1">
                @foreach (['visible' => 'Live', 'hidden' => 'Hidden', 'all' => 'All'] as $key => $label)
                    <a href="{{ route('admin.reviews.index', array_merge($carry, ['show' => $key])) }}"
                       class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                        {{ $label }}
                        @if ($key !== 'all')<span class="text-xs text-slate-400">{{ $counts[$key] }}</span>@endif
                    </a>
                @endforeach
            </div>
            <form method="GET" class="flex items-center gap-2 ml-auto">
                <input type="hidden" name="show" value="{{ $show }}">
                <input type="hidden" name="role" value="{{ $role }}">
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

        {{--
            Who is being reviewed, which is a different question from whether
            the review is live. A worker called unreliable and an employer
            called a late payer are different problems and used to arrive in
            one stream you had to read row by row to separate.
        --}}
        <div class="flex gap-1">
            @foreach (['all' => 'Everyone', 'worker' => 'Workers reviewed', 'employer' => 'Employers reviewed'] as $key => $label)
                <a href="{{ route('admin.reviews.index', array_merge($carry, ['role' => $key === 'all' ? null : $key])) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $role === $key ? 'bg-slate-800 text-white font-medium' : 'text-slate-500 hover:bg-slate-50 border border-slate-200' }}">
                    {{ $label }}
                    <span class="text-xs {{ $role === $key ? 'text-slate-300' : 'text-slate-400' }}">{{ $roleCounts[$key] }}</span>
                </a>
            @endforeach
        </div>
    </div>

    <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
            <tr>
                <th class="text-left font-medium px-5 py-3 w-16">Stars</th>
                <th class="text-left font-medium px-5 py-3 w-48">Written by</th>
                <th class="text-left font-medium px-5 py-3 w-48">About</th>
                <th class="text-left font-medium px-5 py-3">Review</th>
                <th class="text-left font-medium px-5 py-3 w-56">Action</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
            @forelse ($reviews as $review)
                <tr class="{{ $review->isHidden() ? 'bg-slate-50' : '' }} align-top">
                    <td class="px-5 py-4">
                        <p class="text-2xl font-bold text-slate-800 leading-none">{{ $review->rating }}</p>
                        <p class="text-xs text-slate-400 mt-1">of 5</p>
                    </td>

                    <td class="px-5 py-4">
                        @if ($review->reviewer)
                            <a href="{{ route('admin.users.show', $review->reviewer) }}"
                               class="text-slate-800 font-medium hover:text-blue-600">{{ $review->reviewer->name }}</a>
                        @else
                            <span class="text-slate-400">Deleted account</span>
                        @endif
                        <p class="text-xs text-slate-400 mt-0.5">
                            as {{ $review->reviewee_role === 'worker' ? 'employer' : 'worker' }}
                        </p>
                    </td>

                    <td class="px-5 py-4">
                        @if ($review->reviewee)
                            <a href="{{ route('admin.users.show', $review->reviewee) }}"
                               class="text-slate-800 font-medium hover:text-blue-600">{{ $review->reviewee->name }}</a>
                        @else
                            <span class="text-slate-400">Deleted account</span>
                        @endif
                        <p class="mt-1">
                            <span class="text-xs px-2 py-0.5 rounded-full {{ $review->reviewee_role === 'worker' ? 'bg-emerald-50 text-emerald-700' : 'bg-blue-50 text-blue-700' }}">
                                as {{ $review->reviewee_role }}
                            </span>
                        </p>
                    </td>

                    <td class="px-5 py-4">
                        <p class="text-slate-800 whitespace-pre-line">{{ $review->comment ?: 'No comment, stars only.' }}</p>
                        @if ($review->tags)
                            <div class="flex flex-wrap gap-1.5 mt-2">
                                @foreach ($review->tags as $tag)
                                    <span class="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">{{ $tag }}</span>
                                @endforeach
                            </div>
                        @endif
                        <p class="text-xs text-slate-400 mt-2">
                            {{ $review->created_at->format('M j, Y') }}
                            @if ($review->job)
                                &middot; <a href="{{ route('admin.jobs.show', $review->job) }}" class="text-blue-600">{{ $review->job->title }}</a>
                            @endif
                        </p>
                        @if ($review->isHidden())
                            <p class="text-xs text-red-600 mt-2">
                                Hidden {{ $review->hidden_at->format('M j, Y') }} by {{ $review->hider?->name ?? 'admin' }}: {{ $review->hidden_reason }}
                            </p>
                        @endif
                    </td>

                    <td class="px-5 py-4">
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
                    </td>
                </tr>
            @empty
                <tr><td colspan="5" class="p-8 text-center text-slate-400 text-sm">No reviews match.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="p-5">{{ $reviews->links() }}</div>
</div>
@endsection
