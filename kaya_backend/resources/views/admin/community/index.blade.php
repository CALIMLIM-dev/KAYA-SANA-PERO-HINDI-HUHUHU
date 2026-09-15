@extends('admin.layouts.app')
@section('page-title', 'Community')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <div class="flex gap-1">
            @foreach (['live' => 'Live', 'ended' => 'Ended', 'removed' => 'Removed', 'all' => 'All'] as $key => $label)
                <a href="{{ route('admin.community.index', array_filter(['show' => $key, 'search' => $search])) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                    {{ $label }}
                    @if (isset($counts[$key]))<span class="text-xs text-slate-400">{{ $counts[$key] }}</span>@endif
                </a>
            @endforeach
        </div>
        <form method="GET" class="flex items-center gap-2 ml-auto">
            <input type="hidden" name="show" value="{{ $show }}">
            <input type="text" name="search" value="{{ $search }}" placeholder="Words in the post or the poster's name"
                   class="w-72 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Search</button>
        </form>
    </div>

    <div class="divide-y divide-slate-50">
        @forelse ($posts as $post)
            <div class="p-5 flex gap-5 {{ $post->status === 'removed' ? 'bg-slate-50' : '' }}">
                @if ($post->photo_url)
                    <a href="{{ $post->photo_url }}" target="_blank" rel="noopener" class="w-20 h-20 flex-shrink-0 rounded-lg overflow-hidden border border-slate-200 bg-slate-50">
                        <img src="{{ $post->photo_url }}" class="w-full h-full object-cover" alt="">
                    </a>
                @else
                    <div class="w-20 h-20 flex-shrink-0 rounded-lg bg-slate-100 flex items-center justify-center text-xs text-slate-400">No photo</div>
                @endif
                <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                        <span class="text-xs px-2 py-0.5 rounded-full {{ $post->type === 'business' ? 'bg-blue-50 text-blue-700' : 'bg-slate-100 text-slate-600' }}">
                            {{ $post->type === 'business' ? 'Business' : 'Worker' }}
                        </span>
                        <p class="font-medium text-slate-800">{{ $post->title }}</p>
                    </div>
                    <p class="text-sm text-slate-700 mt-1 whitespace-pre-line">{{ $post->body }}</p>
                    <p class="text-xs text-slate-400 mt-2">
                        @if ($post->user)
                            <a href="{{ route('admin.users.show', $post->user) }}" class="text-slate-600 hover:text-blue-600">{{ $post->user->name }}</a>
                        @else Deleted account @endif
                        @if ($post->category) &middot; {{ $post->category->name }} @endif
                        @if ($post->location) &middot; {{ $post->location }} @endif
                        &middot; posted {{ $post->created_at->format('M j') }}
                        &middot; {{ $post->isLive() ? 'ends ' . $post->expires_at->format('M j') : ucfirst($post->status === 'live' ? 'ended' : $post->status) }}
                    </p>
                    @if ($post->status === 'removed')
                        <p class="text-xs text-red-600 mt-1">Removed by {{ $post->remover?->name ?? 'admin' }}: {{ $post->removed_reason }}</p>
                    @endif
                </div>
                @if ($post->status !== 'removed')
                    <form method="POST" action="{{ route('admin.community.remove', $post) }}" class="w-56 flex-shrink-0" onsubmit="return confirm('Remove this post?')">
                        @csrf
                        <input type="text" name="reason" required maxlength="255" placeholder="Reason the poster will see"
                               class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
                        <button class="w-full px-3 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm hover:bg-red-100">Remove</button>
                    </form>
                @endif
            </div>
        @empty
            <p class="p-8 text-center text-slate-400 text-sm">No posts match.</p>
        @endforelse
    </div>

    <div class="p-5">{{ $posts->links() }}</div>
</div>
@endsection
