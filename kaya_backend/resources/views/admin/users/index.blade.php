@extends('admin.layouts.app')
@section('page-title', 'User Management')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <form method="GET" class="flex items-center gap-3 flex-1">
            <input type="text" name="search" value="{{ request('search') }}" placeholder="Search by name or email…"
                   class="flex-1 max-w-xs px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">

            <select name="user_type" class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="">All Types</option>
                <option value="worker" @selected(request('user_type')==='worker')>Worker</option>
                <option value="employer" @selected(request('user_type')==='employer')>Employer</option>
            </select>

            <select name="status" class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="">All Statuses</option>
                <option value="verified" @selected(request('status')==='verified')>Verified</option>
                <option value="pending" @selected(request('status')==='pending')>Pending</option>
                <option value="suspended" @selected(request('status')==='suspended')>Suspended</option>
            </select>

            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Filter</button>
        </form>
    </div>

    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">Name</th>
                <th class="py-3 px-5">Type</th>
                <th class="py-3 px-5">Joined</th>
                <th class="py-3 px-5">Status</th>
                <th class="py-3 px-5 text-right">Actions</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($users as $user)
                <tr class="border-b border-slate-50 hover:bg-slate-50">
                    <td class="py-3 px-5">
                        <div class="flex items-center gap-3">
                            <div class="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-xs font-semibold text-slate-600">
                                {{ strtoupper(substr($user->name, 0, 1)) }}
                            </div>
                            <div>
                                <p class="font-medium text-slate-700">{{ $user->name }}</p>
                                <p class="text-xs text-slate-400">{{ $user->email }}</p>
                            </div>
                        </div>
                    </td>
                    <td class="py-3 px-5 text-slate-500">{{ $user->roleLabel() }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $user->created_at->format('M j, Y') }}</td>
                    <td class="py-3 px-5">
                        @if ($user->is_suspended)
                            <span class="badge-suspended text-xs px-2 py-1 rounded-full">Suspended</span>
                        @elseif ($user->is_verified)
                            <span class="badge-verified text-xs px-2 py-1 rounded-full">Verified</span>
                        @else
                            <span class="badge-pending text-xs px-2 py-1 rounded-full">Pending</span>
                        @endif
                    </td>
                    <td class="py-3 px-5 text-right">
                        <a href="{{ route('admin.users.show', $user) }}" class="text-blue-600 text-xs font-medium">View Details</a>
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <div class="p-5">{{ $users->links() }}</div>
</div>
@endsection
