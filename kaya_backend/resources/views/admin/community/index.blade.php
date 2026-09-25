@extends('admin.layouts.app')
@section('page-title', 'Community')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <div class="flex gap-1">
            {{-- Waiting first: those posters have paid and cannot be seen by anybody until this screen is looked at. --}}
            @foreach (['pending' => 'Waiting', 'live' => 'Live', 'ended' => 'Ended', 'rejected' => 'Refused', 'removed' => 'Removed', 'all' => 'All'] as $key => $label)
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
            <div class="p-5 flex gap-5 {{ in_array($post->status, ['removed', 'rejected']) ? 'bg-slate-50' : '' }}">
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
                        @if ($post->status === 'pending')
                            <span class="text-xs px-2 py-0.5 rounded-full bg-amber-50 text-amber-700">Waiting</span>
                        @endif
                        <p class="font-medium text-slate-800">{{ $post->title }}</p>
                    </div>
                    <p class="text-sm text-slate-700 mt-1 whitespace-pre-line">{{ $post->body }}</p>
                    <p class="text-xs text-slate-400 mt-2">
                        @if ($post->user)
                            <a href="{{ route('admin.users.show', $post->user) }}" class="text-slate-600 hover:text-blue-600">{{ $post->user->name }}</a>
                        @else Deleted account @endif
                        @if ($post->category) &middot; {{ $post->category->name }} @endif
                        @if ($post->location) &middot; {{ $post->location }} @endif
                        &middot; written {{ $post->created_at->format('M j') }}
                        @if ($post->isLive())
                            &middot; ends {{ $post->expires_at->format('M j') }}
                        @elseif ($post->status === 'pending')
                            &middot; its days start when you approve it
                        @else
                            &middot; {{ ucfirst($post->status === 'live' ? 'ended' : $post->status) }}
                        @endif
                    </p>
                    @if (in_array($post->status, ['removed', 'rejected']))
                        <p class="text-xs text-red-600 mt-1">
                            {{ $post->status === 'rejected' ? 'Refused' : 'Removed' }}
                            by {{ $post->remover?->name ?? 'admin' }}: {{ $post->removed_reason }}
                        </p>
                    @endif

                    {{-- The thread, so a post is judged with what it attracted rather than on its own. --}}
                    @if ($post->comments->isNotEmpty())
                        <div class="mt-3 border-l-2 border-slate-100 pl-3 space-y-2">
                            @foreach ($post->comments as $comment)
                                <div class="flex items-start gap-2">
                                    <p class="text-xs text-slate-600 flex-1">
                                        <span class="text-slate-400">{{ $comment->user?->name ?? 'Deleted account' }}:</span>
                                        {{ $comment->body }}
                                    </p>
                                    <form method="POST" action="{{ route('admin.community.comment.remove', $comment) }}"
                                          onsubmit="return confirm('Remove this comment?')" class="flex items-center gap-1">
                                        @csrf
                                        <input type="text" name="reason" required maxlength="255" placeholder="Reason"
                                               class="w-32 px-2 py-1 border border-slate-200 rounded text-xs">
                                        <button class="px-2 py-1 text-xs text-red-600 border border-red-200 rounded hover:bg-red-50">Remove</button>
                                    </form>
                                </div>
                            @endforeach
                        </div>
                    @endif
                </div>

                <div class="w-56 flex-shrink-0 space-y-2">
                    @if ($post->status === 'pending')
                        <form method="POST" action="{{ route('admin.community.approve', $post) }}">
                            @csrf
                            <button class="w-full px-3 py-2 bg-green-50 text-green-700 border border-green-200 rounded-lg text-sm hover:bg-green-100">Approve</button>
                        </form>
                        <form method="POST" action="{{ route('admin.community.reject', $post) }}" onsubmit="return confirm('Refuse this post and return the Barya?')">
                            @csrf
                            <input type="text" name="reason" required maxlength="255" placeholder="Reason the poster will see"
                                   class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
                            <button class="w-full px-3 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm hover:bg-red-100">Refuse</button>
                        </form>
                    @elseif (! in_array($post->status, ['removed', 'rejected']))
                        <form method="POST" action="{{ route('admin.community.remove', $post) }}" onsubmit="return confirm('Remove this post?')">
                            @csrf
                            <input type="text" name="reason" required maxlength="255" placeholder="Reason the poster will see"
                                   class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
                            <button class="w-full px-3 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm hover:bg-red-100">Remove</button>
                        </form>
                    @endif
                </div>
            </div>
        @empty
            <p class="p-8 text-center text-slate-400 text-sm">No posts match.</p>
        @endforelse
    </div>

    <div class="p-5">{{ $posts->links() }}</div>
</div>
@endsection
