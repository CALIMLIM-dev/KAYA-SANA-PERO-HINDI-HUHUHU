@extends('admin.layouts.app')
@section('page-title', 'Appeals & Bans > Violation')

@section('content')

{{--
    One violation: what it was, what it does and until when, where it came
    from, and the appeal against it.
--}}
@php
    $at = fn ($d) => $d ? $d->copy()->timezone('Asia/Manila')->format('M j, Y g:i A') : null;
    $day = fn ($d) => $d ? $d->copy()->timezone('Asia/Manila')->format('M j, Y') : null;
    $name = $strike->user->name ?? 'Deleted account';
    $heading = 'text-sm font-semibold text-slate-800';
    $card = 'rounded-lg border border-slate-200 px-4 py-3';
    $admin = auth()->user();
    $step = $strike->stepNumber();
    $ordinal = $step . (in_array($step % 100, [11, 12, 13], true) ? 'th' : (['th', 'st', 'nd', 'rd'][$step % 10] ?? 'th'));
    $status = $strike->removed_at ? 'Removed ' . $day($strike->removed_at) : ($strike->isActive() ? 'Active' : 'Expired');
    $suspendedNow = $strike->action === 'suspension' && ! $strike->removed_at && $strike->ends_at?->isFuture();
@endphp

<a href="{{ route('admin.strikes.index') }}" class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800">
    <i data-lucide="arrow-left" class="w-4 h-4"></i>
    Appeals & Bans
</a>

<div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-4 items-start">
    <article class="xl:col-span-2 bg-white rounded-xl border border-slate-200 divide-y divide-slate-200">
        <header class="px-6 py-5">
            <h2 class="text-lg font-semibold text-slate-900">{{ $strike->ruleLabel() }}</h2>
            <p class="mt-1 text-sm text-slate-500 flex flex-wrap items-center gap-x-2">
                @include('admin.partials.avatar', ['user' => $strike->user, 'class' => 'w-6 h-6 text-xs'])
                @if ($strike->user)
                    <a href="{{ route('admin.users.show', $strike->user_id) }}" class="font-medium text-slate-800 hover:text-blue-600">{{ $name }}</a>
                @else
                    {{ $name }}
                @endif
                · Given by {{ $strike->issuer->name ?? 'an admin' }} on {{ $at($strike->created_at) }}
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">Penalty</dt>
                    <dd class="mt-0.5 font-medium text-slate-900">{{ $strike->actionLabel() }}</dd>
                </div>
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">{{ $strike->action === 'ban' ? 'Banned' : ($strike->action === 'suspension' ? 'Suspended Until' : 'Ends') }}</dt>
                    <dd class="mt-0.5 font-medium text-slate-900">{{ $strike->endsLabel() }}</dd>
                </div>
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">Status</dt>
                    <dd class="mt-0.5 font-medium text-slate-900">{{ $status }}</dd>
                </div>
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">Severity</dt>
                    <dd class="mt-0.5 text-slate-900">{{ $strike->severityLabel() }}</dd>
                </div>
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">Step</dt>
                    <dd class="mt-0.5 text-slate-900">{{ $ordinal }} violation counting</dd>
                </div>
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">Stops Counting On</dt>
                    <dd class="mt-0.5 text-slate-900">{{ $day($strike->expires_at) }}</dd>
                </div>
                <div class="{{ $card }}">
                    <dt class="text-xs text-slate-500">Can Appeal Until</dt>
                    <dd class="mt-0.5 text-slate-900">{{ $day($strike->appealDeadline()) }}</dd>
                </div>
                <div class="{{ $card }} sm:col-span-2">
                    <dt class="text-xs text-slate-500">Came From</dt>
                    <dd class="mt-0.5 text-slate-900">
                        @if ($strike->report)
                            <a href="{{ route('admin.reports.show', $strike->report) }}" class="text-blue-600 hover:text-blue-700">
                                Report: {{ $strike->report->typeLabel() }} · {{ $strike->report->reasonLabel() }}
                            </a>
                        @else
                            Added from the account page by {{ $strike->issuer->name ?? 'an admin' }}
                        @endif
                    </dd>
                </div>
            </dl>
        </header>

        <section class="px-6 py-5">
            <h3 class="{{ $heading }}">Sent to Them</h3>
            <p class="mt-2 text-sm text-slate-800 leading-relaxed max-w-prose">{{ $strike->finding }}</p>
        </section>

        <section class="px-6 py-5">
            <h3 class="{{ $heading }}">Appeal</h3>
            @if ($strike->appealed_at)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $strike->appeal }}</p>
                <p class="mt-1.5 text-xs text-slate-500">
                    Sent {{ $at($strike->appealed_at) }}
                    @if ($strike->appeal_status === 'pending') · waiting {{ $strike->appealed_at->diffForHumans(null, true) }} @endif
                </p>
                @if ($strike->appeal_status !== 'pending')
                    <p class="mt-3 text-sm text-slate-700">
                        <span class="font-medium">{{ $strike->appeal_status === 'overturned' ? 'Accepted' : 'Refused' }}</span>
                        by {{ $strike->appealDecider->name ?? 'an admin' }} on {{ $at($strike->appeal_decided_at) }}
                    </p>
                @endif
            @else
                <p class="mt-2 text-sm text-slate-500">{{ $strike->canAppeal() ? 'No appeal yet.' : 'No appeal was made.' }}</p>
            @endif
        </section>

        @if ($others->isNotEmpty())
            <section class="px-6 py-5">
                <h3 class="{{ $heading }}">Other Violations</h3>
                <ul class="mt-3 divide-y divide-slate-200 border-y border-slate-200">
                    @foreach ($others as $s)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.strikes.show', $s) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $s->ruleLabel() }} · {{ $s->actionLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $day($s->created_at) }}</span>
                            <span class="w-20 text-right text-xs text-slate-600">{{ $s->removed_at ? 'Removed' : ($s->isActive() ? 'Active' : 'Expired') }}</span>
                        </li>
                    @endforeach
                </ul>
            </section>
        @endif
    </article>

    <aside class="bg-white rounded-xl border border-slate-200 divide-y divide-slate-200 xl:sticky xl:top-24 text-sm">
        <div class="px-6 py-4">
            <h3 class="text-base font-semibold text-slate-900">Actions</h3>
        </div>

        @if ($errors->any())
            <p class="px-6 py-3 text-red-700" role="alert">{{ $errors->first() }}</p>
        @endif

        @if ($strike->appeal_status === 'pending')
            <form method="POST" action="{{ route('admin.strikes.appeal', $strike) }}" class="px-6 py-5">
                @csrf
                <p class="font-medium text-slate-800">Decide the Appeal</p>
                <div class="mt-2 flex gap-5">
                    <label class="flex items-center gap-2 text-slate-700">
                        <input type="radio" name="decision" value="overturned" required class="accent-blue-600">
                        Accept
                    </label>
                    <label class="flex items-center gap-2 text-slate-700">
                        <input type="radio" name="decision" value="upheld" required class="accent-blue-600">
                        Refuse
                    </label>
                </div>
                <button type="submit"
                        class="mt-3 w-full px-3 py-2 bg-slate-800 text-white font-medium rounded-lg hover:bg-slate-900">Submit</button>
            </form>
        @endif

        <div class="px-6 py-5 space-y-2">
            @if (($suspendedNow || ($strike->action === 'ban' && ! $strike->removed_at)) && $strike->user?->is_suspended && $admin->adminCan('suspend'))
                <form method="POST" action="{{ route('admin.users.activate', $strike->user_id) }}"
                      onsubmit="return confirm('End the {{ $strike->action === 'ban' ? 'ban' : 'suspension' }} on {{ addslashes($name) }} now?');">
                    @csrf
                    <button class="w-full px-3 py-2 bg-green-600 text-white font-medium rounded-lg hover:bg-green-700">
                        {{ $strike->action === 'ban' ? 'End Ban' : 'End Suspension Early' }}
                    </button>
                </form>
            @endif
            @if (! $strike->removed_at)
                <form method="POST" action="{{ route('admin.strikes.remove', $strike) }}"
                      onsubmit="return confirm('Remove this violation? It will no longer count against {{ addslashes($name) }}.');">
                    @csrf
                    <button class="w-full px-3 py-2 border border-slate-300 text-slate-700 font-medium rounded-lg hover:bg-slate-50">Remove Violation</button>
                </form>
            @endif
            @if ($strike->user && $admin->adminCan('support'))
                <a href="{{ route('admin.support.user', $strike->user_id) }}"
                   class="block w-full px-3 py-2 text-center border border-slate-300 text-slate-700 font-medium rounded-lg hover:bg-slate-50">Message {{ $name }}</a>
            @endif
            @if ($strike->user)
                <a href="{{ route('admin.users.show', $strike->user_id) }}"
                   class="block w-full px-3 py-2 text-center text-blue-600 font-medium hover:text-blue-700">View User Details</a>
            @endif
        </div>
    </aside>
</div>
@endsection
