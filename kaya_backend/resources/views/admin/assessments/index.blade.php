@extends('admin.layouts.app')
@section('page-title', 'Skill Checks')

@section('content')
@if ($errors->any())
    <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
@endif

<div class="bg-white rounded-xl border border-slate-200 p-5 mb-6 max-w-2xl">
    <h3 class="text-sm font-semibold text-slate-700 mb-3">Add a skill check</h3>
    <form method="POST" action="{{ route('admin.assessments.store') }}" class="flex items-end gap-3">
        @csrf
        <div class="flex-1">
            <label class="text-xs text-slate-500">Trade</label>
            <select name="category_id" required class="w-full mt-1 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="">Choose</option>
                @foreach ($withoutTest as $c)
                    <option value="{{ $c->id }}">{{ $c->name }}</option>
                @endforeach
            </select>
        </div>
        <div class="w-32">
            <label class="text-xs text-slate-500">Pass mark</label>
            <div class="flex items-center gap-1 mt-1">
                <input type="number" name="pass_mark" value="70" min="50" max="100" required class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <span class="text-sm text-slate-500">%</span>
            </div>
        </div>
        <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium h-[38px]">Add</button>
    </form>
</div>

<div class="space-y-4">
    @forelse ($assessments as $a)
        <div class="bg-white rounded-xl border border-slate-200 {{ $a->is_active ? '' : 'opacity-70' }}">
            <div class="p-5 flex items-center gap-4 border-b border-slate-100">
                <div class="flex-1">
                    <p class="font-semibold text-slate-800">{{ $a->category?->name }} skill check</p>
                    <p class="text-xs text-slate-400 mt-0.5">
                        {{ $a->questions->count() }} question{{ $a->questions->count() === 1 ? '' : 's' }}
                        &middot; {{ $a->passes_count }} passed of {{ $a->attempts_count }} attempt{{ $a->attempts_count === 1 ? '' : 's' }}
                        @if ($a->questions->isEmpty()) &middot; <span class="text-amber-600">not offered until it has questions</span> @endif
                        @unless ($a->is_active) &middot; <span class="text-red-600">off</span> @endunless
                    </p>
                </div>
                <form method="POST" action="{{ route('admin.assessments.update', $a) }}" class="flex items-center gap-3">
                    @csrf
                    <label class="text-xs text-slate-500">Pass mark</label>
                    <input type="number" name="pass_mark" value="{{ $a->pass_mark }}" min="50" max="100" class="w-20 px-2 py-1.5 border border-slate-300 rounded-lg text-sm">
                    <label class="flex items-center gap-1.5 text-xs text-slate-600">
                        <input type="checkbox" name="is_active" value="1" @checked($a->is_active)> On
                    </label>
                    <button class="px-3 py-1.5 border border-slate-300 text-slate-700 rounded-lg text-xs">Save</button>
                </form>
                <button type="button" onclick="document.getElementById('qs-{{ $a->id }}').classList.toggle('hidden')"
                        class="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-xs font-medium">Questions</button>
            </div>

            <div id="qs-{{ $a->id }}" class="hidden p-5 bg-slate-50 rounded-b-xl space-y-4">
                @foreach ($a->questions as $i => $q)
                    <form method="POST" action="{{ route('admin.assessments.questions.update', $q) }}" class="bg-white border border-slate-200 rounded-lg p-4">
                        @csrf
                        <div class="flex items-start gap-3">
                            <span class="text-xs font-semibold text-slate-400 mt-2 w-6">{{ $i + 1 }}.</span>
                            <div class="flex-1 space-y-2">
                                <input type="text" name="prompt" value="{{ $q->prompt }}" required maxlength="500"
                                       class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm font-medium">
                                @foreach ($q->choices as $k => $choice)
                                    <label class="flex items-center gap-2">
                                        <input type="radio" name="answer_index" value="{{ $k }}" @checked($q->answer_index === $k) title="Mark as the right answer">
                                        <input type="text" name="choices[]" value="{{ $choice }}" required maxlength="200"
                                               class="flex-1 px-3 py-1.5 border border-slate-300 rounded-lg text-sm">
                                    </label>
                                @endforeach
                                <p class="text-xs text-slate-400">The ticked one is the right answer.</p>
                            </div>
                            <div class="flex flex-col gap-2">
                                <button class="px-3 py-1.5 border border-slate-300 text-slate-700 rounded-lg text-xs">Save</button>
                                <button type="submit" formaction="{{ route('admin.assessments.questions.destroy', $q) }}" formnovalidate
                                        onclick="return confirm('Remove this question?')"
                                        class="px-3 py-1.5 border border-red-200 text-red-600 rounded-lg text-xs">Remove</button>
                            </div>
                        </div>
                    </form>
                @endforeach

                <form method="POST" action="{{ route('admin.assessments.questions.store', $a) }}" class="bg-white border border-dashed border-slate-300 rounded-lg p-4">
                    @csrf
                    <p class="text-xs font-semibold text-slate-500 mb-2">New question</p>
                    <input type="text" name="prompt" required maxlength="500" placeholder="The question"
                           class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm font-medium mb-2">
                    @for ($k = 0; $k < 4; $k++)
                        <label class="flex items-center gap-2 mb-2">
                            <input type="radio" name="answer_index" value="{{ $k }}" @checked($k === 0)>
                            <input type="text" name="choices[]" required maxlength="200" placeholder="Choice {{ $k + 1 }}"
                                   class="flex-1 px-3 py-1.5 border border-slate-300 rounded-lg text-sm">
                        </label>
                    @endfor
                    <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-xs font-medium">Add question</button>
                </form>
            </div>
        </div>
    @empty
        <p class="text-sm text-slate-400">No skill checks yet.</p>
    @endforelse
</div>
@endsection
