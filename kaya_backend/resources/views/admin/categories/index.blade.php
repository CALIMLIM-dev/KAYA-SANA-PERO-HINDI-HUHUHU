@extends('admin.layouts.app')
@section('page-title', 'Categories & Skills')

{{--
    One category per card, and each card has one calm row.

    What was here put three separate forms side by side on every row: a bare
    text input that looked like a heading with a tiny "Rename" link after it, a
    "Merge into" dropdown that deletes the category, and a button reading
    "Switch off" while the badge beside it read "Off" - so the label described
    the action and the badge described the state, and the two looked like they
    disagreed.

    Now the row shows the name and what depends on it, and everything that
    changes the category lives inside one panel the reader has to open. Nothing
    destructive sits a stray click away from a rename.

    The panel is a <details>, so it needs no JavaScript and keeps working with
    the keyboard. The onclick toggle it replaces did neither.
--}}

@section('content')
<div class="mb-6 max-w-xl">
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">New category</h3>
        <p class="text-xs text-slate-400 mb-3">A trade workers pick from and jobs are posted under.</p>
        <form method="POST" action="{{ route('admin.categories.store') }}" class="flex gap-2">
            @csrf
            <input type="text" name="name" required maxlength="60" placeholder="e.g. Carpentry"
                   class="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
                Add category
            </button>
        </form>
    </div>
</div>

<div class="mb-6 max-w-3xl">
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Skill synonyms</h3>
        <p class="text-xs text-slate-400 mb-3">Two names for the same work, such as Screen Replacement and LCD Replacement. Once linked, jobs and workers using either name match each other.</p>
        <form method="POST" action="{{ route('admin.skill-aliases.store') }}" class="flex flex-wrap gap-2">
            @csrf
            <input type="text" name="term_a" required maxlength="120" placeholder="e.g. Screen Replacement"
                   class="flex-1 min-w-[10rem] px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <input type="text" name="term_b" required maxlength="120" placeholder="e.g. LCD Replacement"
                   class="flex-1 min-w-[10rem] px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
                Link
            </button>
        </form>

        @if ($aliases->isNotEmpty())
            <ul class="mt-4 divide-y divide-slate-100 border-t border-slate-100">
                @foreach ($aliases as $alias)
                    <li class="py-2 flex items-center justify-between gap-3 text-sm">
                        <span class="text-slate-700">{{ $alias->term_a }} <span class="text-slate-400">=</span> {{ $alias->term_b }}</span>
                        <form method="POST" action="{{ route('admin.skill-aliases.destroy', $alias) }}">
                            @csrf
                            <button class="text-xs text-slate-500 hover:text-red-600">Unlink</button>
                        </form>
                    </li>
                @endforeach
            </ul>
        @endif
    </div>
</div>

@if ($errors->any())
    <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
@endif

<div class="space-y-3">
    @foreach ($categories as $category)
        @php
            $skillCount = $category->skills_count;
            $workerCount = $workersByCategory[$category->id] ?? 0;
        @endphp

        <div class="bg-white rounded-xl border border-slate-200 {{ $category->is_active ? '' : 'bg-slate-50' }}">
            {{-- The row: what this category is, and what depends on it. --}}
            <div class="p-4 flex flex-wrap items-center gap-x-4 gap-y-2">
                <div class="min-w-0">
                    <p class="text-sm font-semibold text-slate-800">{{ $category->name }}</p>
                    <div class="flex items-center gap-2 mt-1">
                        @unless ($category->is_active)
                            {{-- What the flag actually does: the app's category
                                 list only returns active rows. "Off" said
                                 nothing about what was off. --}}
                            <span class="badge-suspended px-2 py-0.5 rounded-full text-xs">Hidden from the app</span>
                        @endunless
                        @if ($category->is_custom)
                            {{-- Neutral, not the pending badge. Nothing here is
                                 waiting on a decision; a worker simply typed
                                 this name instead of picking one. --}}
                            <span class="px-2 py-0.5 rounded-full text-xs bg-slate-100 text-slate-600">
                                Added by {{ $category->creator?->name ?? 'a user' }}
                            </span>
                        @endif
                    </div>
                </div>

                {{-- Counts, each said in full. A run of bare numbers made the
                     reader work out which was which from the order. --}}
                <div class="ml-auto flex items-center gap-5 text-xs text-slate-500">
                    <span><span class="font-semibold text-slate-700">{{ $category->jobs_count }}</span> jobs, {{ $category->open_jobs_count }} open</span>
                    <span><span class="font-semibold text-slate-700">{{ $workerCount }}</span> workers</span>
                    <span><span class="font-semibold text-slate-700">{{ $skillCount }}</span> skills</span>
                </div>
            </div>

            <details class="border-t border-slate-100 group">
                <summary class="px-4 py-2.5 text-xs font-medium text-blue-600 cursor-pointer select-none hover:bg-slate-50">
                    <span class="group-open:hidden">Edit category and skills</span>
                    <span class="hidden group-open:inline">Close</span>
                </summary>

                <div class="px-4 pb-4 pt-1 bg-slate-50 rounded-b-xl space-y-5">

                    {{-- Rename. A labelled field with a Save button, rather
                         than an unbordered box that read as a heading. --}}
                    <form method="POST" action="{{ route('admin.categories.update', $category) }}">
                        @csrf
                        <label class="block">
                            <span class="block text-xs font-semibold text-slate-700 mb-1.5">Category name</span>
                            <span class="flex gap-2">
                                <input type="text" name="name" value="{{ $category->name }}" required maxlength="60"
                                       class="w-72 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                                <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-xs font-medium hover:bg-blue-700">
                                    Save name
                                </button>
                            </span>
                        </label>
                    </form>

                    {{-- Skills under this category. --}}
                    <div>
                        <h4 class="text-xs font-semibold text-slate-700 mb-2">
                            Skills in {{ $category->name }}
                        </h4>

                        <div class="grid grid-cols-1 md:grid-cols-2 gap-2 mb-3">
                            @forelse ($category->skills as $skill)
                                @php
                                    $skillWorkers = $workersBySkill[$skill->id] ?? 0;
                                    $skillJobs = $jobsBySkill[$skill->id] ?? 0;
                                @endphp
                                <div class="flex items-center gap-2 bg-white border border-slate-200 rounded-lg px-2 py-1.5">
                                    <form method="POST" action="{{ route('admin.skills.update', $skill) }}" class="flex items-center gap-1 flex-1 min-w-0">
                                        @csrf
                                        <input type="text" name="name" value="{{ $skill->name }}" required maxlength="60"
                                               class="flex-1 min-w-0 px-2 py-1 border border-slate-200 rounded text-sm">
                                        <button class="text-xs text-blue-600 font-medium shrink-0">Save</button>
                                    </form>

                                    <span class="text-xs text-slate-400 whitespace-nowrap shrink-0">
                                        {{ $skillWorkers }} workers, {{ $skillJobs }} jobs
                                    </span>

                                    @if ($skillWorkers === 0 && $skillJobs === 0)
                                        {{-- Only when nothing points at it. A skill
                                             somebody has listed cannot be deleted
                                             out from under them, which is why this
                                             button is absent rather than disabled. --}}
                                        <form method="POST" action="{{ route('admin.skills.destroy', $skill) }}"
                                              onsubmit="return confirm('Delete the skill {{ addslashes($skill->name) }}? Nothing is using it.')">
                                            @csrf
                                            <button class="text-xs text-red-600 font-medium shrink-0">Delete</button>
                                        </form>
                                    @endif
                                </div>
                            @empty
                                <p class="text-sm text-slate-400 md:col-span-2">
                                    No skills yet. Workers picking this category will have nothing to choose from.
                                </p>
                            @endforelse
                        </div>

                        <form method="POST" action="{{ route('admin.categories.skills.store', $category) }}" class="flex gap-2">
                            @csrf
                            <input type="text" name="name" required maxlength="60" placeholder="e.g. Cabinet making"
                                   class="w-72 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-xs font-medium hover:bg-blue-700">
                                Add skill
                            </button>
                        </form>
                    </div>

                    {{-- The two that change what exists, kept apart from the
                         rest and said in full. Merge deletes a category, and
                         the old inline dropdown gave no sign of that until the
                         confirm box appeared. --}}
                    <div class="border-t border-slate-200 pt-4 space-y-3">
                        <form method="POST" action="{{ route('admin.categories.toggle', $category) }}"
                              class="flex items-center gap-3">
                            @csrf
                            <button class="px-3 py-2 rounded-lg text-xs font-medium {{ $category->is_active ? 'bg-slate-200 text-slate-700 hover:bg-slate-300' : 'bg-green-600 text-white hover:bg-green-700' }}">
                                {{ $category->is_active ? 'Hide from the app' : 'Show in the app' }}
                            </button>
                            <span class="text-xs text-slate-500">
                                {{ $category->is_active
                                    ? 'Workers and employers can pick this category. Hiding it leaves existing jobs and profiles alone.'
                                    : 'Nobody can pick this category right now. Existing jobs and profiles still use it.' }}
                            </span>
                        </form>

                        <form method="POST" action="{{ route('admin.categories.merge', $category) }}"
                              class="flex flex-wrap items-center gap-2"
                              onsubmit="return confirm('Move every job, worker and skill under {{ addslashes($category->name) }} into the chosen category, then delete {{ addslashes($category->name) }}? This cannot be undone.')">
                            @csrf
                            <span class="text-xs font-semibold text-slate-700">Merge into</span>
                            <select name="into" required class="px-2 py-2 border border-slate-300 rounded-lg text-xs">
                                <option value="">Choose a category</option>
                                @foreach ($categories->where('id', '!=', $category->id) as $other)
                                    <option value="{{ $other->id }}">{{ $other->name }}</option>
                                @endforeach
                            </select>
                            <button class="px-3 py-2 border border-red-300 text-red-600 rounded-lg text-xs font-medium hover:bg-red-50">
                                Merge and delete
                            </button>
                            <span class="text-xs text-slate-500 basis-full">
                                Moves everything under {{ $category->name }} to the chosen category, then deletes {{ $category->name }}.
                            </span>
                        </form>
                    </div>
                </div>
            </details>
        </div>
    @endforeach
</div>
@endsection
