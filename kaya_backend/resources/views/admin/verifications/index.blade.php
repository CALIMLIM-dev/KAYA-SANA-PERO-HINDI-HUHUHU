@extends('admin.layouts.app')
@section('page-title', 'User Management > Verifications')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex gap-2">
        @foreach (['pending' => 'Pending', 'verified' => 'Verified', 'rejected' => 'Rejected', 'all' => 'All'] as $key => $label)
            <a href="{{ route('admin.verifications.index', ['status' => $key]) }}"
               class="px-3 py-1.5 rounded-full text-xs font-medium {{ $status === $key ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-600' }}">
                {{ $label }}
            </a>
        @endforeach
    </div>

    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">Applicant</th>
                <th class="py-3 px-5">Document Type</th>
                <th class="py-3 px-5">Submitted</th>
                <th class="py-3 px-5">Status</th>
                <th class="py-3 px-5 text-right">Action</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($verifications as $v)
                <tr class="border-b border-slate-50 hover:bg-slate-50">
                    <td class="py-3 px-5 font-medium text-slate-700">{{ $v->user->name }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ str_replace('_', ' ', ucfirst($v->document_type)) }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $v->created_at->format('M j, Y') }}</td>
                    <td class="py-3 px-5">
                        <span class="text-xs px-2 py-1 rounded-full
                            {{ $v->status === 'verified' ? 'badge-verified' : ($v->status === 'rejected' ? 'badge-suspended' : 'badge-pending') }}">
                            {{ ucfirst($v->status) }}
                        </span>
                    </td>
                    <td class="py-3 px-5 text-right">
                        <a href="{{ route('admin.verifications.show', $v) }}" class="text-blue-600 text-xs font-medium">Review →</a>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <div class="p-5">{{ $verifications->links() }}</div>
</div>
@endsection
