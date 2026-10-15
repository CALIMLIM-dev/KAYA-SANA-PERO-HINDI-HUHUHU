@extends('admin.layouts.app')
@section('page-title', 'Appeals & Bans > Strike')

@section('content')
@php
    $at = fn ($d) => $d ? $d->copy()->timezone('Asia/Manila')->format('M j, Y g:i A') : null;
    $name = $strike->user->name ?? 'Deleted account';
@endphp

<a href="{{ route('admin.strikes.index') }}" class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800">
    <i data-lucide="arrow-left" class="w-4 h-4"></i>
    Appeals & Bans
</a>

<div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-4 items-start">

    <article class="xl:col-span-2 bg-white rounded-xl border border-slate-200 divide-y divide-slate-100">
        <header class="px-6 py-5">
            <h2 class="text-lg font-semibold text-slate-900">{{ $strike->actionLabel() }}</h2>
            <p class="mt-1 text-sm text-slate-500">
                @if ($strike->user)
                    <a href="{{ route('admin.users.show', $strike->user_id) }}" class="font-medium text-slate-800 hover:text-blue-600">{{ $name }}</a>
                @else
                    {{ $name }}
                @endif
                · issued by {{ $strike->issuer->name ?? 'an administrator' }} on {{ $at($strike->created_at) }}
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-4 text-sm">
                <div>
                    <dt class="text-slate-500">Rule</dt>
                    <dd class="mt-0.5 text-slate-900">{{ $strike->ruleLabel() }}</dd>
                    <dd class="text-slate-500 mt-0.5">{{ $strike->ruleDescription() }}</dd>
                </div>
                <div>
                    <dt class="text-slate-500">Standing</dt>
                    <dd class="mt-0.5 text-slate-900">
                        {{ $strike->removed_at ? 'Overturned ' . $at($strike->removed_at) : ($strike->isActive() ? 'Counting until ' . $strike->expires_at->format('M j, Y') : 'Expired') }}
                    </dd>
                    @if ($strike->ends_at && in_array($strike->action, ['restriction', 'suspension', 'ban'], true))
                        <dd class="text-slate-500 mt-0.5">In effect until {{ $at($strike->ends_at) }}</dd>
                    @endif
                    @if ($strike->confirmed_at)
                        <dd class="text-slate-500 mt-0.5">Reviewed by {{ $strike->confirmer->name ?? 'an administrator' }} on {{ $at($strike->confirmed_at) }}</dd>
                    @endif
                </div>
            </dl>
        </header>

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Finding</h3>
            <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $strike->finding }}</p>
            @if ($strike->report)
                <a href="{{ route('admin.reports.show', $strike->report) }}" class="mt-2 inline-block text-sm text-blue-600 hover:text-blue-700">Open the report it came from</a>
            @else
                <p class="mt-2 text-xs text-slate-500">Issued from the account page, not from a report.</p>
            @endif
        </section>

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Appeal</h3>
            @if ($strike->appealed_at)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $strike->appeal }}</p>
                <p class="mt-1.5 text-xs text-slate-500">Sent {{ $at($strike->appealed_at) }}</p>
                @if ($strike->appeal_status !== 'pending')
                    <p class="mt-3 text-sm text-slate-700">
                        {{ $strike->appeal_status === 'overturned' ? 'Accepted' : 'Refused' }}
                        by {{ $strike->appealDecider->name ?? 'an administrator' }} on {{ $at($strike->appeal_decided_at) }}:
                        {{ $strike->appeal_note }}
                    </p>
                @endif
            @else
                <p class="mt-2 text-sm text-slate-500">
                    {{ $strike->canAppeal() ? 'Not appealed. They can until ' . $strike->appealDeadline()->format('M j, Y') . '.' : 'Not appealed.' }}
                </p>
            @endif
        </section>

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Their Other Strikes</h3>
            @if ($others->isEmpty())
                <p class="mt-2 text-sm text-slate-500">None.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-100 border-y border-slate-100">
                    @foreach ($others as $s)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.strikes.show', $s) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $s->actionLabel() }} · {{ $s->ruleLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $s->created_at->format('M j, Y') }}</span>
                            <span class="w-24 text-right text-xs text-slate-500">{{ $s->removed_at ? 'Overturned' : ($s->isActive() ? 'Counting' : 'Expired') }}</span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </section>
    </article>

    <aside class="bg-white rounded-xl border border-slate-200 xl:sticky xl:top-24">
        <div class="px-6 py-5 border-b border-slate-100">
            <h3 class="text-base font-semibold text-slate-900">Decision</h3>
        </div>
        <div class="px-6 py-5 space-y-6 text-sm">
            @if ($errors->any())
                <p class="text-red-700" role="alert">{{ $errors->first() }}</p>
            @endif

            @if ($strike->isPendingBan())
                <div>
                    <p class="font-medium text-slate-800">Permanent ban</p>
                    @if ($mine)
                        <p class="mt-1 text-slate-500">You proposed this ban. Another administrator has to confirm or decline it.</p>
                    @else
                        <p class="mt-1 text-slate-500">
                            Holding as a suspension until {{ $at($strike->ends_at) }}. Confirming makes it permanent and blocks
                            their email, phone and Google account from signing up again. Declining leaves the suspension as it is.
                        </p>
                        <div class="mt-3 grid grid-cols-2 gap-2">
                            <form method="POST" action="{{ route('admin.strikes.confirm', $strike) }}" onsubmit="return confirm('Make this ban permanent?');">
                                @csrf
                                <button class="w-full px-3 py-2 bg-red-600 text-white font-medium rounded-lg hover:bg-red-700">Confirm Ban</button>
                            </form>
                            <form method="POST" action="{{ route('admin.strikes.decline', $strike) }}">
                                @csrf
                                <button class="w-full px-3 py-2 border border-slate-300 text-slate-700 font-medium rounded-lg hover:bg-slate-50">Decline</button>
                            </form>
                        </div>
                    @endif
                </div>
            @endif

            @if ($strike->appeal_status === 'pending')
                <div class="{{ $strike->isPendingBan() ? 'pt-6 border-t border-slate-100' : '' }}">
                    <p class="font-medium text-slate-800">Appeal</p>
                    @if ($mine)
                        <p class="mt-1 text-slate-500">You issued this strike. Another administrator decides the appeal.</p>
                    @else
                        <form method="POST" action="{{ route('admin.strikes.appeal', $strike) }}" class="mt-2">
                            @csrf
                            <label for="appealNote" class="block text-xs text-slate-500">Reason for Your Decision (Sent to Them)</label>
                            <textarea id="appealNote" name="note" rows="4" minlength="10" maxlength="1000" required
                                      class="mt-1 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                             focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">{{ old('note') }}</textarea>
                            <div class="mt-3 grid grid-cols-2 gap-2">
                                <button type="submit" name="decision" value="overturned"
                                        class="px-3 py-2 bg-slate-800 text-white font-medium rounded-lg hover:bg-slate-900">Accept</button>
                                <button type="submit" name="decision" value="upheld"
                                        class="px-3 py-2 border border-slate-300 text-slate-700 font-medium rounded-lg hover:bg-slate-50">Refuse</button>
                            </div>
                            <p class="mt-2 text-xs text-slate-500">Accepting removes the strike and lifts what it limited.</p>
                        </form>
                    @endif
                </div>
            @endif

            @if (! $strike->isPendingBan() && $strike->appeal_status !== 'pending')
                <p class="text-slate-500">Nothing waiting on this strike.</p>
            @endif
        </div>
    </aside>
</div>
@endsection
