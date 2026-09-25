@extends('admin.layouts.app')
@section('page-title', 'Administrators')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100">
        <p class="font-medium text-slate-800">Who can do what</p>
        <p class="text-sm text-slate-500 mt-1">
            An administrator account is made the same way any account is made, then given
            one of these here.
        </p>
        <dl class="mt-4 space-y-1.5">
            @foreach ($roles as $role)
                <div class="flex gap-3 text-sm">
                    <dt class="w-32 flex-shrink-0 font-medium text-slate-700">{{ $role->label() }}</dt>
                    <dd class="text-slate-500">{{ $role->description() }}</dd>
                </div>
            @endforeach
        </dl>
    </div>

    <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
            <tr>
                <th class="text-left font-medium px-5 py-3">Name</th>
                <th class="text-left font-medium px-5 py-3">Email</th>
                <th class="text-left font-medium px-5 py-3">Access</th>
                <th class="text-left font-medium px-5 py-3 w-72">Change</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
            @foreach ($admins as $admin)
                @php $role = \App\Enums\AdminRole::fromUser($admin->admin_role); @endphp
                <tr class="{{ $admin->is_suspended ? 'bg-slate-50 text-slate-400' : '' }}">
                    <td class="px-5 py-3 text-slate-800">
                        {{ $admin->name }}
                        @if ($admin->id === auth()->id())
                            <span class="text-xs text-slate-400">(you)</span>
                        @endif
                        @if ($admin->is_suspended)
                            <span class="text-xs text-red-500">suspended</span>
                        @endif
                    </td>
                    <td class="px-5 py-3 text-slate-500">{{ $admin->email }}</td>
                    <td class="px-5 py-3">
                        <span class="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">{{ $role->label() }}</span>
                    </td>
                    <td class="px-5 py-3">
                        {{-- Changing your own access is refused in the controller; no point offering it. --}}
                        @if ($admin->id === auth()->id())
                            <span class="text-xs text-slate-400">You cannot change your own access.</span>
                        @else
                            <form method="POST" action="{{ route('admin.admins.role', $admin) }}" class="flex items-center gap-2">
                                @csrf
                                <select name="admin_role" class="px-3 py-1.5 border border-slate-300 rounded-lg text-sm">
                                    @foreach ($roles as $option)
                                        <option value="{{ $option->value }}" @selected($option === $role)>{{ $option->label() }}</option>
                                    @endforeach
                                </select>
                                <button class="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-sm">Save</button>
                            </form>
                        @endif
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
</div>
@endsection
