@extends('admin.layouts.app')
@section('page-title', 'Settings')

@section('content')
<form method="POST" action="{{ route('admin.settings.update') }}" class="max-w-3xl">
    @csrf

    @if ($errors->any())
        <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
    @endif

    <div class="bg-white rounded-xl border border-slate-200 p-6">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Pricing</h3>

        <div class="grid grid-cols-2 gap-x-8 gap-y-4">
            @foreach ($fields as $key => $field)
                <label class="block">
                    <span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $field['label'] }}</span>
                    <span class="flex items-center gap-2">
                        <input type="number" name="{{ \App\Support\Pricing::formName($key) }}"
                               value="{{ old(\App\Support\Pricing::formName($key), $field['value']) }}"
                               min="{{ $field['min'] }}" max="{{ $field['max'] }}" step="1" required
                               class="w-28 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                        <span class="text-xs text-slate-500">{{ $field['unit'] }}</span>
                    </span>
                </label>
            @endforeach
        </div>
    </div>

    <button class="mt-5 px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
        Save prices
    </button>
</form>
@endsection
