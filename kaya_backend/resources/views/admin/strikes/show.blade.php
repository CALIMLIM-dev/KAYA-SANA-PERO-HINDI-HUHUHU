@extends('admin.layouts.app')
@section('page-title', 'Appeals & Bans > Violation')

@section('content')
@php
    $at = fn ($d) => $d ? $d->copy()->timezone('Asia/Manila')->format('M j, Y g:i A') : null;
    $name = $strike->user->name ?? 'Deleted account';
    $section = 'px-6 py-5';
    $heading = 'text-sm font-semibold text-slate-800';
    $admin = auth()->user();
@endphp

<a href="{{ route('admin.strikes.index') }}" class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800">
    <i data-lucide="arrow-left" class="w-4 h-4"></i>
    Appeals & Bans
</a>

<div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-4 items-start">

    <article class="xl:col-span-2 bg-white rounded-xl border border-slate-200 divide-y divide-slate-200">
        <header class="{{ $section }}">
            <h2 class="text-lg font-semibold text-slate-900">{{ $strike->actionLabel() }}</h2>
            <p class="mt-1 text-sm text-slate-500">
                @if ($strike->user)
                    <a href="{{ route('admin.users.show', $strike->user_id) }}" class="font-medium text-slate-800 hover:text-blue-600">{{ $name }}</a>
                @else
                    {{ $name }}
                @endif
                · given by {{ $strike->issuer->name ?? 'an admin' }} on {{ $at($strike->created_at) }}
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                <div class="rounded-lg border border-slate-200 px-4 py-3">
                    <dt class="text-xs text-slate-500">Violation</dt>
                    <dd class="mt-0.5 text-slate-900">{{ $strike->ruleLabel() }}</dd>
                </div>
                <div class="rounded-lg border border-slate-200 px-4 py-3">
                    <dt class="text-xs text-slate-500">Status</dt>
                    <dd class="mt-0.5 text-slate-900">
                        {{ $strike->removed_at ? 'Removed ' . $at($strike->removed_at) : ($strike->action === 'ban' ? 'Permanent' : ($strike->isActive() ? 'Active until ' . $strike->expires_at->format('M j, Y') : 'Expired')) }}
                    </dd>
                    @if ($strike->ends_at && in_array($strike->action, ['restriction', 'suspension'], true))
                        <dd class="mt-0.5 text-xs text-slate-500">Penalty ends {{ $at($strike->ends_at) }}</dd>
                    @endif
                </div>
            </dl>
        </header>

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Finding</h3>
            <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $strike->finding }}</p>
            @if ($strike->report)
                <a href="{{ route('admin.reports.show', $strike->report) }}" class="mt-2 inline-block text-sm text-blue-600 hover:text-blue-700">Open Report</a>
            @endif
        </section>

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Review Request</h3>
            @if ($strike->appealed_at)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $strike->appeal }}</p>
                <p class="mt-1.5 text-xs text-slate-500">{{ $at($strike->appealed_at) }}</p>
                @if ($strike->appeal_status !== 'pending')
                    <p class="mt-3 text-sm text-slate-700">
                        {{ $strike->appeal_status === 'overturned' ? 'Accepted' : 'Refused' }}
                        by {{ $strike->appealDecider->name ?? 'an admin' }} on {{ $at($strike->appeal_decided_at) }}:
                        {{ $strike->appeal_note }}
                    </p>
                @endif
            @else
                <p class="mt-2 text-sm text-slate-500">None.</p>
            @endif
        </section>

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Other Violations</h3>
            @if ($others->isEmpty())
                <p class="mt-2 text-sm text-slate-500">None.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-200 border-y border-slate-200">
                    @foreach ($others as $s)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.strikes.show', $s) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $s->actionLabel() }} · {{ $s->ruleLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $s->created_at->format('M j, Y') }}</span>
                            <span class="w-20 text-right text-xs text-slate-600">{{ $s->removed_at ? 'Removed' : ($s->isActive() ? 'Active' : 'Expired') }}</span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </section>
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
                <p class="font-medium text-slate-800">Decide the Review Request</p>
                {{-- Choosing fills the note with the ready-made words for it. --}}
                <div class="mt-2 flex gap-5">
                    <label class="flex items-center gap-2 text-slate-700">
                        <input type="radio" name="decision" value="overturned" required class="accent-blue-600"
                               data-note="{{ \App\Support\ModerationReasons::REVIEW_ACCEPTED }}" @checked(old('decision') === 'overturned')>
                        Accept
                    </label>
                    <label class="flex items-center gap-2 text-slate-700">
                        <input type="radio" name="decision" value="upheld" required class="accent-blue-600"
                               data-note="{{ \App\Support\ModerationReasons::REVIEW_REFUSED }}" @checked(old('decision') === 'upheld')>
                        Refuse
                    </label>
                </div>
                <label for="appealNote" class="block mt-3 text-sm font-medium text-slate-800">Note (Optional)</label>
                <textarea id="appealNote" name="note" rows="3" maxlength="1000" data-note-box
                          class="mt-2 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">{{ old('note') }}</textarea>
                <button type="submit"
                        class="mt-3 w-full px-3 py-2 bg-slate-800 text-white font-medium rounded-lg hover:bg-slate-900">Save Decision</button>
            </form>
        @endif

        <div class="px-6 py-5 space-y-2">
            @if ($strike->user?->is_suspended && $admin->adminCan('suspend'))
                <form method="POST" action="{{ route('admin.users.activate', $strike->user_id) }}"
                      onsubmit="return confirm('Lift the suspension on {{ addslashes($name) }}?');">
                    @csrf
                    <button class="w-full px-3 py-2 bg-green-600 text-white font-medium rounded-lg hover:bg-green-700">Lift Suspension</button>
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
                   class="block w-full px-3 py-2 text-center text-blue-600 font-medium hover:text-blue-700">Open Account</a>
            @endif
        </div>
    </aside>
</div>
@endsection
