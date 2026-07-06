@extends('admin.layouts.app')
@section('page-title', 'User Management > Worker Audit')

@section('content')
<div class="grid grid-cols-3 gap-6 max-w-4xl">

    {{-- Identity card --}}
    <div class="col-span-1 bg-white rounded-xl border border-slate-200 p-6 text-center">
        <div class="w-20 h-20 rounded-full bg-slate-200 mx-auto flex items-center justify-center text-2xl font-semibold text-slate-600">
            {{ strtoupper(substr($verification->user->name, 0, 1)) }}
        </div>
        <h2 class="mt-3 font-semibold text-slate-800">{{ $verification->user->name }}</h2>
        <p class="text-xs text-slate-400">{{ ucfirst($verification->user->user_type) }} · {{ $verification->user->city ?? 'No city set' }}</p>

        <div class="mt-4 text-xs px-3 py-1.5 rounded-full inline-block
            {{ $verification->status === 'verified' ? 'badge-verified' : ($verification->status === 'rejected' ? 'badge-suspended' : 'badge-pending') }}">
            {{ ucfirst($verification->status) }}
        </div>

        <dl class="mt-5 text-left text-sm space-y-2 border-t border-slate-100 pt-4">
            <div class="flex justify-between"><dt class="text-slate-400">Document</dt><dd>{{ str_replace('_',' ',ucfirst($verification->document_type)) }}</dd></div>
            @if ($verification->document_type === 'government_id' && $verification->id_type)
                <div class="flex justify-between"><dt class="text-slate-400">ID Type</dt><dd>{{ $verification->id_type }}</dd></div>
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
                        <img src="{{ asset('storage/' . $verification->document_front_url) }}" class="h-full w-full object-contain rounded-lg">
                    @else
                        <span>{{ $verification->document_type === 'business_reg' ? 'Business document' : 'Front of ID' }} - not uploaded</span>
                    @endif
                </div>
                <div class="border border-slate-200 rounded-lg h-36 flex items-center justify-center bg-slate-50 text-xs text-slate-400 overflow-hidden">
                    @if ($verification->selfie_url)
                        <img src="{{ asset('storage/' . $verification->selfie_url) }}" class="h-full w-full object-contain rounded-lg">
                    @else
                        <span>{{ $verification->document_type === 'business_reg' ? 'No selfie required' : 'Selfie - not uploaded' }}</span>
                    @endif
                </div>
            </div>
        </div>

        @if ($verification->status === 'pending')
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700 mb-3">Decision</h3>
                <div class="flex gap-3">
                    <form method="POST" action="{{ route('admin.verifications.approve', $verification) }}">
                        @csrf
                        <button class="px-5 py-2.5 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700">
                            ✓ Approve Verification
                        </button>
                    </form>

                    <button onclick="document.getElementById('rejectForm').classList.toggle('hidden')"
                            class="px-5 py-2.5 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm font-medium hover:bg-red-100">
                        ✕ Reject
                    </button>
                </div>

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

<a href="{{ route('admin.verifications.index') }}" class="inline-block mt-6 text-sm text-blue-600 font-medium">← Back to Verifications</a>
@endsection
