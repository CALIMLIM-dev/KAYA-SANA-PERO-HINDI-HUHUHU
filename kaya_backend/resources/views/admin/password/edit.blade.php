@extends('admin.layouts.app')
@section('page-title', 'Your Password')

@section('content')
<div class="max-w-md bg-white rounded-xl border border-slate-200 p-6">
    @if ($forced)
        <p class="text-sm font-medium text-slate-800">Choose your own password</p>
        <p class="text-sm text-slate-500 mt-1">
            The one you signed in with was made for you, and the person who made your account has seen it.
            Replace it to open the rest of the panel.
        </p>
    @else
        <p class="text-sm font-medium text-slate-800">Change your password</p>
    @endif

    @if ($errors->any())
        <div class="mt-4 px-3 py-2 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
    @endif

    <form method="POST" action="{{ route('admin.password.update') }}" class="mt-5 space-y-4">
        @csrf
        <div>
            <label for="current_password" class="block text-xs font-semibold text-slate-700 mb-1.5">Current password</label>
            <input id="current_password" type="password" name="current_password" required autocomplete="current-password"
                   class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
        </div>
        <div>
            <label for="password" class="block text-xs font-semibold text-slate-700 mb-1.5">New password</label>
            <input id="password" type="password" name="password" required autocomplete="new-password"
                   class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <p class="text-xs text-slate-500 mt-1">At least 8 characters, with letters and numbers.</p>
        </div>
        <div>
            <label for="password_confirmation" class="block text-xs font-semibold text-slate-700 mb-1.5">New password again</label>
            <input id="password_confirmation" type="password" name="password_confirmation" required autocomplete="new-password"
                   class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
        </div>
        <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Save password</button>
    </form>
</div>
@endsection
