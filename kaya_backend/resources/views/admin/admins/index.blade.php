@extends('admin.layouts.app')
@section('page-title', 'Administrators')

@section('content')

{{--
    The password of an account just made, once.

    Flashed by AdminTeamController::store, so it is on this page load and on
    no other. It is not stored anywhere readable; the new admin replaces it
    at their first sign-in.
--}}
@if ($created = session('created'))
    <div class="mb-6 bg-white rounded-xl border border-blue-200 p-5" role="status">
        <p class="font-medium text-slate-800">{{ $created['name'] }} can sign in now, as {{ $created['role'] }}</p>
        <p class="text-sm text-slate-500 mt-1">
            Give them these. The password is shown only this once, and they will be asked to choose their own
            when they first sign in.
        </p>
        <dl class="mt-4 grid grid-cols-[6rem_1fr] gap-y-2 text-sm max-w-xl">
            <dt class="text-slate-500">Sign in at</dt>
            <dd class="text-slate-800">{{ route('admin.login') }}</dd>
            <dt class="text-slate-500">Email</dt>
            <dd class="text-slate-800">{{ $created['email'] }}</dd>
            <dt class="text-slate-500">Password</dt>
            <dd class="flex items-center gap-3">
                <code id="new-admin-password" class="px-2 py-1 rounded bg-slate-100 text-slate-800 tracking-wide">{{ $created['password'] }}</code>
                <button type="button" class="text-xs font-medium text-blue-600 hover:text-blue-700"
                        onclick="navigator.clipboard.writeText(document.getElementById('new-admin-password').textContent).then(() => { this.textContent = 'Copied' })">
                    Copy
                </button>
            </dd>
        </dl>
    </div>
@endif

<div class="bg-white rounded-xl border border-slate-200">
    {{-- New administrator. The password is generated, never typed. --}}
    <div class="p-5 border-b border-slate-100">
        <p class="font-medium text-slate-800">New Administrator</p>
        @if ($errors->any())
            <div class="mt-3 px-3 py-2 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
        @endif
        <form method="POST" action="{{ route('admin.admins.store') }}" class="mt-4 flex flex-wrap items-end gap-3">
            @csrf
            <div>
                <label for="admin-name" class="block text-xs font-semibold text-slate-700 mb-1.5">Name</label>
                <input id="admin-name" type="text" name="name" value="{{ old('name') }}" required maxlength="255"
                       class="w-56 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            </div>
            <div>
                <label for="admin-email" class="block text-xs font-semibold text-slate-700 mb-1.5">Email</label>
                <input id="admin-email" type="email" name="email" value="{{ old('email') }}" required maxlength="255"
                       class="w-64 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            </div>
            <div>
                <label for="admin-role" class="block text-xs font-semibold text-slate-700 mb-1.5">Role</label>
                <select id="admin-role" name="admin_role" required class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                    {{-- No default: the first role in the list is Super admin. --}}
                    <option value="">Choose a role</option>
                    @foreach ($roles as $option)
                        <option value="{{ $option->value }}" @selected(old('admin_role') === $option->value)>{{ $option->label() }}</option>
                    @endforeach
                </select>
            </div>
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Add administrator</button>
        </form>
    </div>

    <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-500">
            <tr>
                <th class="text-left font-medium px-5 py-3">Name</th>
                <th class="text-left font-medium px-5 py-3">Email</th>
                <th class="text-left font-medium px-5 py-3">Access</th>
                <th class="text-left font-medium px-5 py-3 w-72">Change</th>
                <th class="px-5 py-3"><span class="sr-only">Remove</span></th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
            @foreach ($admins as $admin)
                @php $role = \App\Enums\AdminRole::fromUser($admin->admin_role); @endphp
                <tr class="{{ $admin->is_suspended ? 'bg-slate-50 text-slate-400' : '' }}">
                    <td class="px-5 py-3 text-slate-800">
                        {{-- The name, editable in place. --}}
                        <form method="POST" action="{{ route('admin.admins.rename', $admin) }}" class="flex items-center gap-2">
                            @csrf
                            <label for="admin-name-{{ $admin->id }}" class="sr-only">Name</label>
                            <input id="admin-name-{{ $admin->id }}" type="text" name="name" value="{{ $admin->name }}" required maxlength="255"
                                   class="w-48 px-2 py-1 border border-transparent hover:border-slate-200 focus:border-slate-300 rounded text-sm">
                            <button class="text-xs font-medium text-blue-600 hover:text-blue-700">Save</button>
                        </form>
                        @if ($admin->id === auth()->id())
                            <span class="text-xs text-slate-400">(you)</span>
                        @endif
                        @if ($admin->is_suspended)
                            <span class="text-xs text-red-500">suspended</span>
                        @endif
                        @if ($admin->must_change_password)
                            <span class="text-xs text-slate-400">has not signed in yet</span>
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
                    <td class="px-5 py-3 text-right">
                        @if ($admin->id !== auth()->id())
                            <form method="POST" action="{{ route('admin.admins.remove', $admin) }}"
                                  onsubmit="return confirm('Remove {{ addslashes($admin->name) }}? They are signed out and can no longer sign in. Their actions stay in the audit log.')">
                                @csrf
                                <button class="text-xs font-medium text-slate-500 hover:text-red-600">Remove</button>
                            </form>
                        @endif
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>
</div>
@endsection
