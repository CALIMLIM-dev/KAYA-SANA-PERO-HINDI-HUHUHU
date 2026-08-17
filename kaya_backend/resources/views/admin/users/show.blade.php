@extends('admin.layouts.app')
@section('page-title', 'User Detail')

@section('content')
<div class="grid grid-cols-[1fr,600px] gap-4 px-4">
    {{-- Left Column: User Details + Verifications/Skills --}}
    <div class="space-y-4">
        {{-- User Details Card (RED) --}}
        <div class="bg-white rounded-xl border border-slate-200 p-6">
        <div class="flex items-center gap-4 mb-6">
            <div class="w-14 h-14 rounded-full bg-slate-200 flex items-center justify-center text-lg font-semibold text-slate-600 overflow-hidden">
                @if ($user->workerProfile && $user->workerProfile->profile_photo)
                    <img src="{{ asset('storage/' . $user->workerProfile->profile_photo) }}" class="w-full h-full object-cover" alt="{{ $user->name }}">
                @else
                    {{ strtoupper(substr($user->name, 0, 1)) }}
                @endif
            </div>
            <div>
                <h2 class="text-lg font-semibold text-slate-800">{{ $user->name }}</h2>
                <p class="text-sm text-slate-400">{{ $user->email }} · {{ $user->roleLabel() }}</p>
            </div>
            <div class="ml-auto flex items-center gap-3">
                @if ($user->is_suspended)
                    <span class="badge-suspended text-xs px-3 py-1.5 rounded-full">Suspended</span>
                    <form method="POST" action="{{ route('admin.users.activate', $user) }}" class="inline">
                        @csrf
                        <button type="submit" class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg hover:bg-green-700">
                            Reactivate Account
                        </button>
                    </form>
                @elseif ($user->is_verified)
                    <span class="badge-verified text-xs px-3 py-1.5 rounded-full">Verified</span>
                    <button onclick="openSuspendModal()"
                            class="px-4 py-2 bg-red-50 text-red-600 border border-red-200 text-sm rounded-lg hover:bg-red-100">
                        Suspend Account
                    </button>
                @else
                    <span class="badge-pending text-xs px-3 py-1.5 rounded-full">Pending</span>
                    <button onclick="openSuspendModal()"
                            class="px-4 py-2 bg-red-50 text-red-600 border border-red-200 text-sm rounded-lg hover:bg-red-100">
                        Suspend Account
                    </button>
                @endif
            </div>
        </div>

        @if ($user->is_suspended && $user->suspended_reason)
            <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                <h3 class="text-sm font-semibold text-red-900 mb-1">Suspension Reason</h3>
                <p class="text-sm text-red-700">{{ $user->suspended_reason }}</p>
            </div>
        @endif

        <dl class="grid grid-cols-2 gap-4 text-sm mb-6">
            <div><dt class="text-slate-400">Phone</dt><dd class="text-slate-700">{{ $user->phone ?? '—' }}</dd></div>
            <div><dt class="text-slate-400">City</dt><dd class="text-slate-700">{{ $user->city ?? '—' }}</dd></div>
            <div><dt class="text-slate-400">Joined</dt><dd class="text-slate-700">{{ $user->created_at->format('M j, Y') }}</dd></div>
            <div><dt class="text-slate-400">Last Updated</dt><dd class="text-slate-700">{{ $user->updated_at->format('M j, Y') }}</dd></div>
        </dl>

        @if ($user->postedJobs->count())
            <h3 class="text-sm font-semibold text-slate-700 mb-2">Recent Job Posts</h3>
            <ul class="text-sm space-y-1 mb-4">
                @foreach ($user->postedJobs as $job)
                    <li class="text-slate-600">{{ $job->title }} <span class="text-slate-400">· {{ $job->status }}</span></li>
                @endforeach
            </ul>
        @endif
        </div>

        {{-- Blue Panel: Verifications + Skills --}}
        @if ($user->workerProfile)
            {{-- Verifications Section --}}
            @if ($user->verifications->count() > 0)
                <div class="bg-white rounded-xl border border-slate-200 p-6">
                    <h3 class="text-sm font-semibold text-slate-700 mb-4">Verifications</h3>
                    <div class="space-y-3">
                            @foreach ($user->verifications as $verification)
                                <div class="border border-slate-200 rounded-lg p-4">
                                    <div class="flex justify-between items-start mb-2">
                                        <h4 class="text-sm font-medium text-slate-700">{{ str_replace('_', ' ', ucfirst($verification->document_type)) }}</h4>
                                        <span class="text-xs px-2 py-1 rounded-full 
                                            {{ $verification->status === 'verified' ? 'badge-verified' : ($verification->status === 'pending' ? 'badge-pending' : 'badge-suspended') }}">
                                            {{ ucfirst($verification->status) }}
                                        </span>
                                    </div>
                                    @if ($verification->document_type === 'government_id')
                                        <p class="text-xs text-slate-500 mb-3">ID Type: {{ $verification->id_type }}</p>
                                        <div class="grid grid-cols-2 gap-2">
                                            @if ($verification->document_front_url)
                                                <div class="relative group cursor-pointer" onclick="showImageModal('{{ route('admin.verifications.document', [$verification, 'front']) }}')">
                                                    <div class="border border-slate-200 rounded h-20 overflow-hidden hover:border-blue-400 transition-colors">
                                                        <img src="{{ route('admin.verifications.document', [$verification, 'front']) }}" class="w-full h-full object-contain bg-slate-50">
                                                    </div>
                                                    <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-opacity rounded flex items-center justify-center">
                                                        <svg class="w-6 h-6 text-white opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>
                                                        </svg>
                                                    </div>
                                                </div>
                                            @endif
                                            @if ($verification->selfie_url)
                                                <div class="relative group cursor-pointer" onclick="showImageModal('{{ route('admin.verifications.document', [$verification, 'selfie']) }}')">
                                                    <div class="border border-slate-200 rounded h-20 overflow-hidden hover:border-blue-400 transition-colors">
                                                        <img src="{{ route('admin.verifications.document', [$verification, 'selfie']) }}" class="w-full h-full object-contain bg-slate-50">
                                                    </div>
                                                    <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-opacity rounded flex items-center justify-center">
                                                        <svg class="w-6 h-6 text-white opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>
                                                        </svg>
                                                    </div>
                                                </div>
                                            @endif
                                        </div>
                                    @endif
                                </div>
                            @endforeach
                    </div>
                </div>
            @endif

            {{-- Skills Section - Grouped by Category --}}
            @if ($user->skills->count() > 0)
                <div class="bg-white rounded-xl border border-slate-200 p-6">
                    <h3 class="text-sm font-semibold text-slate-700 mb-4">Skills ({{ $user->skills->count() }})</h3>
                    
                    @php
                        // Group skills by category
                        $grouped = $user->skills->groupBy(function($skill) {
                            return $skill->categoryName ?? 'Uncategorized';
                        });
                    @endphp
                    
                    @foreach ($grouped as $categoryName => $categorySkills)
                        <div class="mb-4 last:mb-0">
                            {{-- Category Header --}}
                            <h4 class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2 letterspacing-0.5">
                                {{ $categoryName }}
                            </h4>
                            
                            {{-- Skills in this category --}}
                            <div class="flex flex-wrap gap-2">
                                @foreach ($categorySkills as $skill)
                                    <span class="px-3 py-1.5 bg-blue-50 text-blue-700 text-sm rounded-lg border border-blue-100">
                                        {{ $skill->skill_name }}
                                    </span>
                                @endforeach
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        @endif

        <a href="{{ route('admin.users.index') }}" class="inline-block text-sm text-blue-600 font-medium">← Back to Users</a>
    </div>

    {{-- Right Sidebar (BLACK): Work Experience, Certifications, Licenses --}}
    @if ($user->workerProfile)
        <div class="space-y-4">
                {{-- Work Experience Section --}}
                @if ($user->experiences->count() > 0)
                    <div class="bg-white rounded-xl border border-slate-200 p-6">
                        <h3 class="text-sm font-semibold text-slate-700 mb-4">Work Experience ({{ $user->experiences->count() }})</h3>
                        <div class="space-y-3">
                            @foreach ($user->experiences as $exp)
                                <div class="border border-slate-200 rounded-lg p-4">
                                    <h4 class="text-sm font-medium text-slate-700 mb-1">{{ $exp->job_title }}</h4>
                                    <p class="text-xs text-slate-500 mb-2">{{ $exp->company_name }}</p>
                                    <p class="text-xs text-slate-400 mb-2">
                                        {{ \Carbon\Carbon::parse($exp->start_date)->format('M Y') }} - 
                                        {{ $exp->is_current ? 'Present' : \Carbon\Carbon::parse($exp->end_date)->format('M Y') }}
                                    </p>
                                    @if ($exp->description)
                                        <p class="text-xs text-slate-600">{{ $exp->description }}</p>
                                    @endif
                                </div>
                            @endforeach
                        </div>
                    </div>
                @endif

                {{-- Certifications Section --}}
                @if ($user->certifications->count() > 0)
                    <div class="bg-white rounded-xl border border-slate-200 p-6">
                        <h3 class="text-sm font-semibold text-slate-700 mb-4">Certifications ({{ $user->certifications->count() }})</h3>
                        <div class="space-y-3">
                            @foreach ($user->certifications as $cert)
                                <div class="border border-slate-200 rounded-lg p-4">
                                    <h4 class="text-sm font-medium text-slate-700 mb-1">{{ $cert->certification_name }}</h4>
                                    <p class="text-xs text-slate-500 mb-2">{{ $cert->issuing_organization }}</p>
                                    @if ($cert->issue_date)
                                        <p class="text-xs text-slate-400 mb-3">Issued: {{ $cert->issue_date->format('M Y') }}</p>
                                    @endif
                                    @if ($cert->document_path)
                                        <div class="relative group cursor-pointer" onclick="showImageModal('{{ asset('storage/' . $cert->document_path) }}')">
                                            <div class="border border-slate-200 rounded h-32 overflow-hidden hover:border-blue-400 transition-colors mb-2">
                                                <img src="{{ asset('storage/' . $cert->document_path) }}" class="w-full h-full object-contain bg-slate-50">
                                            </div>
                                            <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-opacity rounded flex items-center justify-center">
                                                <svg class="w-8 h-8 text-white opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>
                                                </svg>
                                            </div>
                                        </div>
                                        <a href="{{ asset('storage/' . $cert->document_path) }}" target="_blank" 
                                           class="inline-flex items-center gap-1 text-xs text-blue-600 hover:underline">
                                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                                            </svg>
                                            View Full Document
                                        </a>
                                    @else
                                        <span class="text-xs text-slate-400">No document uploaded</span>
                                    @endif
                                </div>
                            @endforeach
                        </div>
                    </div>
                @endif

                {{-- Licenses Section --}}
                @if ($user->licenses->count() > 0)
                    <div class="bg-white rounded-xl border border-slate-200 p-6">
                        <h3 class="text-sm font-semibold text-slate-700 mb-4">Licenses ({{ $user->licenses->count() }})</h3>
                        <div class="space-y-3">
                            @foreach ($user->licenses as $license)
                                <div class="border border-slate-200 rounded-lg p-4">
                                    <h4 class="text-sm font-medium text-slate-700 mb-1">{{ $license->license_name }}</h4>
                                    <p class="text-xs text-slate-500 mb-2">{{ $license->issuing_authority }}</p>
                                    @if ($license->issue_date)
                                        <p class="text-xs text-slate-400 mb-3">Issued: {{ $license->issue_date->format('M Y') }}</p>
                                    @endif
                                    @if ($license->document_path)
                                        <div class="relative group cursor-pointer" onclick="showImageModal('{{ asset('storage/' . $license->document_path) }}')">
                                            <div class="border border-slate-200 rounded h-32 overflow-hidden hover:border-blue-400 transition-colors mb-2">
                                                <img src="{{ asset('storage/' . $license->document_path) }}" class="w-full h-full object-contain bg-slate-50">
                                            </div>
                                            <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-opacity rounded flex items-center justify-center">
                                                <svg class="w-8 h-8 text-white opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>
                                                </svg>
                                            </div>
                                        </div>
                                        <a href="{{ asset('storage/' . $license->document_path) }}" target="_blank" 
                                           class="inline-flex items-center gap-1 text-xs text-blue-600 hover:underline">
                                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                                            </svg>
                                            View Full Document
                                        </a>
                                    @else
                                        <span class="text-xs text-slate-400">No document uploaded</span>
                                    @endif
                                </div>
                            @endforeach
                        </div>
                </div>
            @endif
        </div>
    @endif
</div>

{{-- Suspend Modal --}}
@if (!$user->is_suspended)
<style>
    .mod-select {
        width: 100%; padding: 9px 32px 9px 12px; border: 1px solid #cbd5e1;
        border-radius: 9px; font-size: 13px; color: #0f172a; background-color: #fff;
        appearance: none; -webkit-appearance: none; cursor: pointer;
    }
    /* Native arrow removed above, so one is drawn back on. */
    .mod-arrow { position: relative; }
    .mod-arrow::after {
        content: ""; position: absolute; right: 12px; top: 50%; width: 9px; height: 9px;
        border-right: 2px solid #64748b; border-bottom: 2px solid #64748b;
        transform: translateY(-70%) rotate(45deg); pointer-events: none;
    }
    .mod-select:focus { outline: none; border-color: #dc2626; box-shadow: 0 0 0 3px rgba(220,38,38,.15); }
    .sev { font-size: 9.5px; font-weight: 700; letter-spacing: .04em; text-transform: uppercase;
           padding: 2px 6px; border-radius: 4px; white-space: nowrap; }
    .sev-critical { background: #fee2e2; color: #b91c1c; }
    .sev-serious  { background: #ffedd5; color: #c2410c; }
    .sev-moderate { background: #fef3c7; color: #b45309; }
</style>

<div id="suspendModal" class="hidden fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-xl max-w-md w-full shadow-2xl">
        <form method="POST" action="{{ route('admin.users.suspend', $user) }}">
            @csrf
            <div class="px-5 py-4 border-b border-slate-200">
                <h3 class="text-base font-semibold text-slate-900">Suspend {{ $user->name }}</h3>
            </div>

            <div class="px-5 py-4 space-y-4">
                {{-- Grouped by severity so the list is scanned rather than read.
                     Options come from the shared catalogue, so the app, the
                     report queue and this dialog cannot disagree on wording. --}}
                <div>
                    <label for="reasonSelect" class="block text-xs font-semibold text-slate-600 mb-1.5">Reason</label>
                    <div class="mod-arrow">
                        <select name="reason_code" id="reasonSelect" class="mod-select" required>
                            <option value="" disabled selected>Choose a reason...</option>
                            @foreach (['critical' => 'Serious, usually permanent', 'serious' => 'Serious', 'moderate' => 'Moderate'] as $sev => $groupLabel)
                                @php $group = collect($suspensionReasons)->filter(fn ($r) => $r['severity'] === $sev); @endphp
                                @if ($group->isNotEmpty())
                                    <optgroup label="{{ $groupLabel }}">
                                        @foreach ($group as $code => $reason)
                                            <option value="{{ $code }}"
                                                    data-days="{{ $reason['default_days'] ?? 'permanent' }}"
                                                    data-severity="{{ $reason['severity'] }}"
                                                    data-description="{{ $reason['description'] }}">{{ $reason['label'] }}</option>
                                        @endforeach
                                    </optgroup>
                                @endif
                            @endforeach
                        </select>
                    </div>

                    {{-- One severity chip, no sentence. The label already says
                         what the reason is. --}}
                    <div id="reasonHint" class="hidden mt-2">
                        <span id="reasonSeverity" class="sev"></span>
                    </div>
                </div>

                <div>
                    <label for="durationSelect" class="block text-xs font-semibold text-slate-600 mb-1.5">Length</label>
                    <div class="mod-arrow">
                        <select name="duration" id="durationSelect" class="mod-select" required>
                            <option value="7">7 days</option>
                            <option value="14">14 days</option>
                            <option value="30">30 days</option>
                            <option value="90">90 days</option>
                            <option value="permanent">Permanent</option>
                        </select>
                    </div>
                </div>

                <div>
                    <label for="suspendNote" class="block text-xs font-semibold text-slate-600 mb-1.5">Note</label>
                    <textarea name="note" id="suspendNote" rows="2" maxlength="1000"
                              class="w-full px-3 py-2 border border-slate-300 rounded-lg text-[13px]
                                     focus:outline-none focus:ring-2 focus:ring-red-500 focus:border-red-500"
                              placeholder="Optional, internal"></textarea>
                </div>
            </div>

            <div class="px-5 py-4 bg-slate-50 rounded-b-xl flex gap-3 border-t border-slate-200">
                <button type="button" onclick="closeSuspendModal()"
                        class="flex-1 px-4 py-2 bg-white border border-slate-300 text-slate-700 text-sm font-semibold rounded-lg hover:bg-slate-50">
                    Cancel
                </button>
                <button type="submit"
                        class="flex-1 px-4 py-2 bg-red-600 text-white text-sm font-semibold rounded-lg hover:bg-red-700">
                    Suspend account
                </button>
            </div>
        </form>
    </div>
</div>

<script>
function openSuspendModal() {
    document.getElementById('suspendModal').classList.remove('hidden');
}

function closeSuspendModal() {
    document.getElementById('suspendModal').classList.add('hidden');
    document.getElementById('reasonSelect').selectedIndex = 0;
    document.getElementById('suspendNote').value = '';
    document.getElementById('reasonHint').classList.add('hidden');
}

// Selecting a reason explains it and pre-fills the length that usually goes
// with it. A starting point, not a rule; the length stays editable.
document.getElementById('reasonSelect')?.addEventListener('change', function () {
    const option = this.options[this.selectedIndex];
    const severity = document.getElementById('reasonSeverity');

    severity.textContent = option.dataset.severity || '';
    severity.className = 'sev sev-' + (option.dataset.severity || 'moderate');
    document.getElementById('reasonHint').classList.remove('hidden');

    document.getElementById('durationSelect').value = option.dataset.days || 'permanent';
});

document.getElementById('suspendModal')?.addEventListener('click', function (e) {
    if (e.target === this) closeSuspendModal();
});
</script>
@endif

{{-- Image zoom lives outside the suspension block on purpose. It used to sit
     inside it, so on a suspended user's page showImageModal was never defined
     and clicking a submitted ID did nothing. --}}
<script>
function showImageModal(imageUrl) {
    const modal = document.getElementById('imageModal');
    const modalImage = document.getElementById('modalImage');
    modalImage.src = imageUrl;
    modal.classList.remove('hidden');
}

function closeImageModal() {
    document.getElementById('imageModal').classList.add('hidden');
}
</script>

{{-- Image Preview Modal --}}
<div id="imageModal" class="hidden fixed inset-0 bg-black bg-opacity-75 z-50 flex items-center justify-center p-4" onclick="closeImageModal()">
    <div class="relative max-w-5xl max-h-[90vh]" onclick="event.stopPropagation()">
        <button onclick="closeImageModal()" class="absolute -top-10 right-0 text-white hover:text-gray-300">
            <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
        </button>
        <img id="modalImage" src="" class="max-w-full max-h-[90vh] object-contain rounded-lg shadow-2xl">
    </div>
</div>

@endsection
