@extends('admin.layouts.app')
@section('page-title', 'Verifications > Review')

@php
    $profile = $verification->user?->employerProfile;
    $needsTinCheck = $verification->document_type !== 'government_id'
        && $profile?->employer_type?->requiresBusinessVerification()
        && filled($profile->tin);
@endphp

@section('content')
<div class="grid grid-cols-3 gap-6 max-w-4xl">

    {{-- Identity card --}}
    <div class="col-span-1 bg-white rounded-xl border border-slate-200 p-6 text-center">
        <div class="w-20 h-20 rounded-full bg-slate-200 mx-auto flex items-center justify-center text-2xl font-semibold text-slate-600">
            {{ strtoupper(substr($verification->user->name, 0, 1)) }}
        </div>
        <h2 class="mt-3 font-semibold text-slate-800">{{ $verification->user->name }}</h2>
        <p class="text-xs text-slate-400">{{ $verification->user->roleLabel() }} · {{ $verification->user->city ?? 'No city set' }}</p>

        <div class="mt-4 text-xs px-3 py-1.5 rounded-full inline-block
            {{ $verification->status === 'verified' ? 'badge-verified' : ($verification->status === 'rejected' ? 'badge-suspended' : 'badge-pending') }}">
            {{ ucfirst($verification->status) }}
        </div>

        <dl class="mt-5 text-left text-sm space-y-2 border-t border-slate-100 pt-4">
            <div class="flex justify-between"><dt class="text-slate-400">Document</dt><dd>{{ str_replace('_',' ',ucfirst($verification->document_type)) }}</dd></div>
            @if ($verification->document_type === 'government_id' && $verification->id_type)
                <div class="flex justify-between"><dt class="text-slate-400">ID Type</dt><dd>{{ $verification->id_type }}</dd></div>
            @endif
            @if ($verification->document_type !== 'government_id' && $profile)
                <div class="flex justify-between"><dt class="text-slate-400">Company</dt><dd class="text-right">{{ $profile->company_name ?: 'Not given' }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-400">TIN</dt><dd class="font-mono">{{ $profile->tin ?: 'Not given' }}</dd></div>
                @if ($profile->tin_verified_at)
                    <div class="flex justify-between"><dt class="text-slate-400">TIN checked</dt><dd class="text-right">{{ $profile->tin_verified_at->format('M j, Y') }}<br><span class="text-xs text-slate-400">by {{ $profile->tinVerifier?->name ?? 'admin' }}</span></dd></div>
                @endif
            @endif
            <div class="flex justify-between"><dt class="text-slate-400">Submitted</dt><dd>{{ $verification->created_at->format('M j, Y') }}</dd></div>
            @if ($verification->reviewed_at)
                <div class="flex justify-between"><dt class="text-slate-400">Reviewed</dt><dd>{{ $verification->reviewed_at->format('M j, Y') }}</dd></div>
            @endif
        </dl>
    </div>

    {{-- Documents + decision --}}
    <div class="col-span-2 space-y-4">
        <div class="bg-white rounded-xl border border-slate-200 p-5">
            <h3 class="text-sm font-semibold text-slate-700 mb-3">Submitted Documents</h3>
            <div class="grid grid-cols-2 gap-3">
                <div class="border border-slate-200 rounded-lg h-36 flex items-center justify-center bg-slate-50 text-xs text-slate-400 overflow-hidden">
                    @if ($verification->document_front_url)
                        <img src="{{ route('admin.verifications.document', [$verification, 'front']) }}" class="h-full w-full object-contain rounded-lg">
                    @else
                        <span>{{ $verification->document_type === 'business_reg' ? 'Business document' : 'Front of ID' }} - not uploaded</span>
                    @endif
                </div>
                <div class="border border-slate-200 rounded-lg h-36 flex items-center justify-center bg-slate-50 text-xs text-slate-400 overflow-hidden">
                    @if ($verification->selfie_url)
                        <img src="{{ route('admin.verifications.document', [$verification, 'selfie']) }}" class="h-full w-full object-contain rounded-lg">
                    @else
                        <span>{{ $verification->document_type === 'business_reg' ? 'No selfie required' : 'Selfie - not uploaded' }}</span>
                    @endif
                </div>
            </div>
        </div>

        @if ($needsTinCheck)
            {{-- BIR has no API. ORUS is its free lookup page, so the check is done by hand and recorded here. --}}
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700 mb-1">Check the TIN with BIR</h3>
                <p class="text-sm text-slate-500">
                    Open ORUS, choose TIN Verification, and enter <span class="font-mono text-slate-800">{{ $profile->tin }}</span>.
                    The registered name BIR shows should match <span class="font-medium text-slate-800">{{ $profile->company_name ?: 'the company name on the document' }}</span>.
                </p>
                <div class="mt-3 flex items-center gap-3">
                    <a href="https://orus.bir.gov.ph" target="_blank" rel="noopener"
                       class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
                        Open ORUS
                    </a>
                    <button type="button" onclick="navigator.clipboard.writeText('{{ $profile->tin }}'); this.textContent='Copied'"
                            class="px-4 py-2 border border-slate-300 text-slate-700 rounded-lg text-sm font-medium hover:bg-slate-50">
                        Copy TIN
                    </button>
                    @if ($profile->tin_verified_at)
                        <span class="text-xs px-2.5 py-1 rounded-full badge-verified">Checked {{ $profile->tin_verified_at->diffForHumans() }}</span>
                    @endif
                </div>
            </div>
        @endif

        @if ($verification->status === 'pending')
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700 mb-3">Decision</h3>
                <form method="POST" action="{{ route('admin.verifications.approve', $verification) }}">
                    @csrf
                    @if ($needsTinCheck)
                        <label class="flex items-start gap-2 mb-3 text-sm text-slate-700">
                            <input type="checkbox" name="tin_checked" value="1" class="mt-0.5">
                            <span>I checked this TIN on ORUS and the registered name matches the company.</span>
                        </label>
                    @endif
                    <div class="flex gap-3">
                        <button class="px-5 py-2.5 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700">
                            Approve
                        </button>
                        <button type="button" onclick="document.getElementById('rejectForm').classList.toggle('hidden')"
                                class="px-5 py-2.5 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm font-medium hover:bg-red-100">
                            Reject
                        </button>
                    </div>
                </form>

                <form id="rejectForm" method="POST" action="{{ route('admin.verifications.reject', $verification) }}" class="hidden mt-4">
                    @csrf
                    <label class="text-xs text-slate-500">Reason for rejection</label>
                    <textarea name="reason" required rows="2"
                              class="w-full mt-1 px-3 py-2 border border-slate-300 rounded-lg text-sm"
                              placeholder="e.g. Document image is blurry, ID number doesn't match name"></textarea>
                    <button class="mt-2 px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium">Confirm Rejection</button>
                </form>
            </div>
        @elseif ($verification->rejection_reason)
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700 mb-1">Rejection Reason</h3>
                <p class="text-sm text-slate-500">{{ $verification->rejection_reason }}</p>
            </div>
        @endif
    </div>
</div>

<a href="{{ route('admin.verifications.index') }}" class="inline-block mt-6 text-sm text-blue-600 font-medium">Back to verifications</a>
@endsection
