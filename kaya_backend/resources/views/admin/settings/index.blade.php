@extends('admin.layouts.app')
@section('page-title', 'User Management > System Configuration')

@section('content')
<form method="POST" action="{{ route('admin.settings.update') }}" class="max-w-2xl space-y-5">
    @csrf

    @foreach ($settings as $group => $items)
        <div class="bg-white rounded-xl border border-slate-200 p-5">
            <h3 class="text-sm font-semibold text-slate-700 mb-1 capitalize">{{ str_replace('_', ' ', $group) }}</h3>
            <p class="text-xs text-slate-400 mb-4">
                @if ($group === 'content_filtering')
                    Control what's allowed in job posts, profiles, and messages.
                @else
                    General platform behavior.
                @endif
            </p>

            <div class="space-y-3">
                @foreach ($items as $setting)
                    <label class="flex items-center justify-between py-2 border-b border-slate-50 last:border-0">
                        <span class="text-sm text-slate-600">{{ $setting->label }}</span>
                        <input type="checkbox" name="{{ $setting->key }}" value="1"
                               @checked($setting->value === '1')
                               class="w-5 h-5 accent-blue-600">
                    </label>
                @endforeach
            </div>
        </div>
    @endforeach

    <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
        Save Configuration
    </button>
</form>
@endsection
