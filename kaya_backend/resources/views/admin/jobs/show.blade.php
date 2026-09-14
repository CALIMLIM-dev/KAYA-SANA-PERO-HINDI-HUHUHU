@extends('admin.layouts.app')
@section('page-title', 'Jobs > ' . $job->title)

@section('content')
@php
    $statusLabel = ['open' => 'Open', 'in_progress' => 'In progress', 'completed' => 'Completed', 'expired' => 'Ended', 'closed' => 'Closed'][$job->status] ?? ucfirst($job->status);
    $badge = ['open' => 'badge-verified', 'in_progress' => 'bg-blue-50 text-blue-700', 'completed' => 'bg-slate-100 text-slate-600',
              'expired' => 'badge-pending', 'closed' => 'badge-suspended'][$job->status] ?? 'bg-slate-100 text-slate-600';
    $appBadge = fn ($s) => ['pending' => 'badge-pending', 'accepted' => 'badge-verified', 'completed' => 'bg-slate-100 text-slate-600',
                            'rejected' => 'badge-suspended', 'cancelled' => 'bg-slate-100 text-slate-500', 'withdrawn' => 'bg-slate-100 text-slate-500'][$s] ?? 'bg-slate-100 text-slate-600';
@endphp

<div class="grid grid-cols-3 gap-6">
    <div class="col-span-2 space-y-4">
        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <div class="flex items-start justify-between gap-4">
                <div>
                    <h2 class="text-lg font-semibold text-slate-800">{{ $job->title }}</h2>
                    <p class="text-sm text-slate-400 mt-0.5">
                        {{ $job->category?->name ?? 'No category' }}
                        @if ($job->city || $job->location) &middot; {{ $job->city ?: $job->location }} @endif
                    </p>
                </div>
                <span class="text-xs px-3 py-1.5 rounded-full {{ $badge }}">{{ $statusLabel }}</span>
            </div>

            <p class="text-sm text-slate-700 mt-4 whitespace-pre-line">{{ $job->description }}</p>

            @if ($job->skills->isNotEmpty())
                <div class="flex flex-wrap gap-2 mt-4">
                    @foreach ($job->skills as $skill)
                        <span class="text-xs px-2 py-1 rounded-full bg-slate-100 text-slate-600">{{ $skill->name }}</span>
                    @endforeach
                </div>
            @endif

            <dl class="grid grid-cols-3 gap-4 text-sm mt-6 border-t border-slate-100 pt-4">
                <div><dt class="text-slate-400">Budget</dt><dd class="text-slate-700">
                    @if ($job->budget_min || $job->budget_max)
                        P{{ number_format($job->budget_min) }}@if ($job->budget_max && $job->budget_max != $job->budget_min) to P{{ number_format($job->budget_max) }}@endif
                        @if ($job->budget_period) per {{ $job->budget_period }} @endif
                    @else Not given @endif
                </dd></div>
                <div><dt class="text-slate-400">Work dates</dt><dd class="text-slate-700">
                    {{ $job->start_date?->format('M j, Y') ?? 'Not set' }}@if ($job->end_date) to {{ $job->end_date->format('M j, Y') }}@endif
                </dd></div>
                <div><dt class="text-slate-400">Post ends</dt><dd class="text-slate-700">{{ $job->expires_at?->format('M j, Y') ?? 'No date' }}</dd></div>
                <div><dt class="text-slate-400">Posted</dt><dd class="text-slate-700">{{ $job->created_at->format('M j, Y g:i A') }}</dd></div>
                <div><dt class="text-slate-400">Address given</dt><dd class="text-slate-700">{{ $job->address_line ?: 'None' }}</dd></div>
                <div><dt class="text-slate-400">Boosted</dt><dd class="text-slate-700">{{ $job->is_urgent ? 'Yes' : 'No' }}</dd></div>
            </dl>
        </div>

        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <h3 class="text-sm font-semibold text-slate-700 mb-3">Applicants ({{ $job->applications->count() }})</h3>
            @forelse ($job->applications as $app)
                <div class="flex items-center justify-between py-2 border-b border-slate-50 text-sm">
                    <div>
                        @if ($app->worker)
                            <a href="{{ route('admin.users.show', $app->worker) }}" class="text-slate-700 hover:text-blue-600">{{ $app->worker->name }}</a>
                            <span class="text-xs text-slate-400">{{ $app->worker->email }}</span>
                        @else
                            <span class="text-slate-400">Deleted account</span>
                        @endif
                    </div>
                    <div class="flex items-center gap-3">
                        <span class="text-xs text-slate-400">{{ $app->created_at->format('M j') }}</span>
                        <span class="text-xs px-2 py-1 rounded-full {{ $appBadge($app->status) }}">{{ ucfirst($app->status) }}</span>
                    </div>
                </div>
            @empty
                <p class="text-sm text-slate-400">Nobody has applied.</p>
            @endforelse
        </div>
    </div>

    <div class="space-y-4">
        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <h3 class="text-sm font-semibold text-slate-700 mb-3">Employer</h3>
            @if ($job->employer)
                <a href="{{ route('admin.users.show', $job->employer) }}" class="font-medium text-slate-800 hover:text-blue-600">{{ $job->employer->name }}</a>
                <p class="text-xs text-slate-400">{{ $job->employer->email }}</p>
                @if ($job->employer->employerProfile?->company_name)
                    <p class="text-sm text-slate-600 mt-2">{{ $job->employer->employerProfile->company_name }}</p>
                @endif
                <p class="text-xs mt-2">
                    @if ($job->employer->is_suspended) <span class="badge-suspended px-2 py-0.5 rounded-full">Suspended</span>
                    @elseif ($job->employer->is_verified) <span class="badge-verified px-2 py-0.5 rounded-full">Verified</span>
                    @else <span class="badge-pending px-2 py-0.5 rounded-full">Not verified</span> @endif
                </p>
            @else
                <p class="text-sm text-slate-400">Account deleted.</p>
            @endif
        </div>

        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <h3 class="text-sm font-semibold text-slate-700 mb-3">Barya on this post</h3>
            @forelse ($charges as $line)
                <div class="flex justify-between text-sm py-1">
                    <span class="text-slate-600">{{ str_replace('_', ' ', ucfirst($line->reason)) }}</span>
                    <span class="{{ $line->delta < 0 ? 'text-red-600' : 'text-green-600' }}">{{ $line->delta > 0 ? '+' : '' }}{{ $line->delta }}</span>
                </div>
            @empty
                <p class="text-sm text-slate-400">Posted free.</p>
            @endforelse
        </div>

        @if (in_array($job->status, ['open', 'in_progress']))
            <div class="bg-white rounded-xl border border-slate-200 p-6">
                <h3 class="text-sm font-semibold text-slate-700 mb-1">Close this post</h3>
                <p class="text-xs text-slate-500 mb-3">Takes it off the feed. Pending applicants are told and get their Barya back. The employer is told the reason.</p>
                <form method="POST" action="{{ route('admin.jobs.close', $job) }}" onsubmit="return confirm('Close this post?')">
                    @csrf
                    <input type="text" name="reason" required maxlength="255" placeholder="Reason the employer will see"
                           class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
                    <button class="w-full px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700">Close post</button>
                </form>
            </div>
        @endif

        @if ($history->isNotEmpty())
            <div class="bg-white rounded-xl border border-slate-200 p-6">
                <h3 class="text-sm font-semibold text-slate-700 mb-3">Admin history</h3>
                @foreach ($history as $h)
                    <div class="text-sm py-1">
                        <p class="text-slate-700">{{ $h->summary }}</p>
                        <p class="text-xs text-slate-400">{{ $h->admin?->name ?? 'Admin' }}, {{ $h->created_at->format('M j, Y g:i A') }}</p>
                    </div>
                @endforeach
            </div>
        @endif
    </div>
</div>

<a href="{{ route('admin.jobs.index') }}" class="inline-block mt-6 text-sm text-blue-600 font-medium">Back to jobs</a>
@endsection
