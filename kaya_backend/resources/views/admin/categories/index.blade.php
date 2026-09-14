@extends('admin.layouts.app')
@section('page-title', 'Categories & Skills')

@section('content')
<div class="flex items-start gap-4 mb-6">
    <div class="bg-white rounded-xl border border-slate-200 p-5 flex-1">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Add a category</h3>
        <p class="text-xs text-slate-500 mb-3">Shows in every picker right away. Add skills under it below.</p>
        <form method="POST" action="{{ route('admin.categories.store') }}" class="flex gap-2">
            @csrf
            <input type="text" name="name" required maxlength="60" placeholder="Category name"
                   class="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Add</button>
        </form>
    </div>
    <div class="bg-white rounded-xl border border-slate-200 p-5 w-80 text-sm text-slate-500">
        <p>{{ $categories->count() }} categories, {{ $categories->where('is_active', true)->count() }} on.</p>
        <p class="mt-1">{{ $categories->where('is_custom', true)->count() }} were added by users.</p>
        <p class="mt-1 text-xs">Switching a category off hides it from pickers. Jobs and profiles already under it keep it.</p>
    </div>
</div>

@if ($errors->any())
    <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
@endif

<div class="space-y-3">
    @foreach ($categories as $category)
        <div class="bg-white rounded-xl border {{ $category->is_active ? 'border-slate-200' : 'border-slate-200 opacity-60' }}">
            <div class="p-4 flex items-center gap-3">
                <form method="POST" action="{{ route('admin.categories.update', $category) }}" class="flex items-center gap-2">
                    @csrf
                    <input type="text" name="name" value="{{ $category->name }}" required maxlength="60"
                           class="px-3 py-1.5 border border-transparent hover:border-slate-300 focus:border-slate-300 rounded-lg text-sm font-semibold text-slate-800 w-64">
                    <button class="text-xs text-blue-600">Rename</button>
                </form>

                <div class="text-xs text-slate-400 flex gap-3">
                    <span>{{ $category->jobs_count }} jobs ({{ $category->open_jobs_count }} open)</span>
                    <span>{{ $workersByCategory[$category->id] ?? 0 }} workers</span>
                    <span>{{ $category->skills_count }} skills</span>
                    @if ($category->is_custom)
                        <span class="badge-pending px-2 py-0.5 rounded-full">Added by {{ $category->creator?->name ?? 'a user' }}</span>
                    @endif
                    @unless ($category->is_active)
                        <span class="badge-suspended px-2 py-0.5 rounded-full">Off</span>
                    @endunless
                </div>

                <div class="ml-auto flex items-center gap-2">
                    <form method="POST" action="{{ route('admin.categories.merge', $category) }}" class="flex items-center gap-1"
                          onsubmit="return confirm('Move everything under {{ addslashes($category->name) }} into the chosen category and delete it?')">
                        @csrf
                        <select name="into" required class="px-2 py-1.5 border border-slate-300 rounded-lg text-xs">
                            <option value="">Merge into</option>
                            @foreach ($categories->where('id', '!=', $category->id) as $other)
                                <option value="{{ $other->id }}">{{ $other->name }}</option>
                            @endforeach
                        </select>
                        <button class="px-3 py-1.5 border border-slate-300 text-slate-600 rounded-lg text-xs">Merge</button>
                    </form>
                    <form method="POST" action="{{ route('admin.categories.toggle', $category) }}">
                        @csrf
                        <button class="px-3 py-1.5 rounded-lg text-xs font-medium {{ $category->is_active ? 'bg-slate-100 text-slate-600' : 'bg-green-600 text-white' }}">
                            {{ $category->is_active ? 'Switch off' : 'Switch on' }}
                        </button>
                    </form>
                    <button type="button" onclick="document.getElementById('skills-{{ $category->id }}').classList.toggle('hidden')"
                            class="px-3 py-1.5 border border-slate-300 text-slate-600 rounded-lg text-xs">Skills</button>
                </div>
            </div>

            <div id="skills-{{ $category->id }}" class="hidden border-t border-slate-100 p-4 bg-slate-50 rounded-b-xl">
                <div class="grid grid-cols-2 gap-2 mb-3">
                    @forelse ($category->skills as $skill)
                        <div class="flex items-center gap-2 text-sm">
                            <form method="POST" action="{{ route('admin.skills.update', $skill) }}" class="flex items-center gap-1 flex-1">
                                @csrf
                                <input type="text" name="name" value="{{ $skill->name }}" required maxlength="60"
                                       class="flex-1 px-2 py-1 border border-transparent hover:border-slate-300 focus:border-slate-300 rounded text-sm bg-transparent">
                                <button class="text-xs text-blue-600">Rename</button>
                            </form>
                            <span class="text-xs text-slate-400 whitespace-nowrap">{{ $workersBySkill[$skill->id] ?? 0 }} workers, {{ $jobsBySkill[$skill->id] ?? 0 }} jobs</span>
                            @if (($workersBySkill[$skill->id] ?? 0) === 0 && ($jobsBySkill[$skill->id] ?? 0) === 0)
                                <form method="POST" action="{{ route('admin.skills.destroy', $skill) }}" onsubmit="return confirm('Remove {{ addslashes($skill->name) }}?')">
                                    @csrf
                                    <button class="text-xs text-red-600">Remove</button>
                                </form>
                            @endif
                        </div>
                    @empty
                        <p class="text-sm text-slate-400 col-span-2">No skills under this category yet.</p>
                    @endforelse
                </div>
                <form method="POST" action="{{ route('admin.categories.skills.store', $category) }}" class="flex gap-2">
                    @csrf
                    <input type="text" name="name" required maxlength="60" placeholder="New skill under {{ $category->name }}"
                           class="w-72 px-3 py-1.5 border border-slate-300 rounded-lg text-sm">
                    <button class="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-xs font-medium">Add skill</button>
                </form>
            </div>
        </div>
    @endforeach
</div>
@endsection
