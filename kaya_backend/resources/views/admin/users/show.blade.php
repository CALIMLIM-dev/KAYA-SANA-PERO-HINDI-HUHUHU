@extends('admin.layouts.app')
@section('page-title', 'User Detail')

@section('content')
<div class="bg-white rounded-xl border border-slate-200 p-6 max-w-2xl">
    <div class="flex items-center gap-4 mb-6">
        <div class="w-14 h-14 rounded-full bg-slate-200 flex items-center justify-center text-lg font-semibold text-slate-600">
            {{ strtoupper(substr($user->name, 0, 1)) }}
        </div>
        <div>
            <h2 class="text-lg font-semibold text-slate-800">{{ $user->name }}</h2>
            <p class="text-sm text-slate-400">{{ $user->email }} · {{ ucfirst($user->user_type) }}</p>
        </div>
        <div class="ml-auto">
            @if ($user->is_suspended)
                <span class="badge-suspended text-xs px-3 py-1.5 rounded-full">Suspended</span>
            @elseif ($user->is_verified)
                <span class="badge-verified text-xs px-3 py-1.5 rounded-full">Verified</span>
            @else
                <span class="badge-pending text-xs px-3 py-1.5 rounded-full">Pending</span>
            @endif
        </div>
    </div>

    <dl class="grid grid-cols-2 gap-4 text-sm mb-6">
        <div><dt class="text-slate-400">Phone</dt><dd class="text-slate-700">{{ $user->phone ?? '—' }}</dd></div>
        <div><dt class="text-slate-400">City</dt><dd class="text-slate-700">{{ $user->city ?? '—' }}</dd></div>
        <div><dt class="text-slate-400">Joined</dt><dd class="text-slate-700">{{ $user->created_at->format('M j, Y') }}</dd></div>
        <div><dt class="text-slate-400">Suspension reason</dt><dd class="text-slate-700">{{ $user->suspended_reason ?? '—' }}</dd></div>
    </dl>

    @if ($user->user_type === 'employer' && $user->postedJobs->count())
        <h3 class="text-sm font-semibold text-slate-700 mb-2">Recent Job Posts</h3>
        <ul class="text-sm space-y-1 mb-4">
            @foreach ($user->postedJobs as $job)
                <li class="text-slate-600">{{ $job->title }} <span class="text-slate-400">· {{ $job->status }}</span></li>
            @endforeach
        </ul>
    @endif

    <a href="{{ route('admin.users.index') }}" class="text-sm text-blue-600 font-medium">← Back to Users</a>
</div>
@endsection
