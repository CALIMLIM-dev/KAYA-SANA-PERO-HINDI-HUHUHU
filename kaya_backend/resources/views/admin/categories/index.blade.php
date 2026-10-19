@extends('admin.layouts.app')
@section('page-title', 'Categories & Skills')

{{--
    A list on the left, one category open on the right.

    It was one card per category, each with an "Edit category and skills"
    drawer, so the page was a column of identical boxes: finding a skill meant
    opening drawers until it turned up, and two open at once pushed the rest
    off the screen. Now the list is short enough to scan, a search finds a
    category by its own name or by any skill under it, and the open category
    has the whole right side.

    The two actions that change what exists stay apart from the edits. Hiding
    is reversible and says what it does. Merging deletes a category, so it sits
    folded at the bottom, names both sides, and asks before it runs.

    Synonyms are their own section below: they pair skill names across
    categories, so they belong to no one category.
--}}

@section('content')
@php
    // "1 worker", "2 workers" - the old rows said "1 workers".
    $count = fn (int $n, string $one, ?string $many = null) => $n . ' ' . ($n === 1 ? $one : ($many ?? $one . 's'));
    $keep = fn (array $params) => array_filter($params + ['q' => $q !== '' ? $q : null], fn ($v) => $v !== null);
    // Hiding, merging and deleting are the owner's (decision D3); a
    // Sub-admin adds and renames. The routes enforce it; this only stops
    // offering what would be refused.
    $canDestroy = auth()->user()->adminCan('catalogue.destroy');
@endphp

@if ($errors->any())
    <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">{{ $errors->first() }}</div>
@endif

{{-- Find, and add. --}}
<div class="flex flex-wrap items-center gap-3 mb-4">
    <form method="GET" action="{{ route('admin.categories.index') }}" class="flex gap-2 flex-1 min-w-[16rem] max-w-md" role="search">
        <label for="category-search" class="sr-only">Find a category or skill</label>
        <input id="category-search" type="search" name="q" value="{{ $q }}" placeholder="Find a category or skill"
               class="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
        <button class="px-3 py-2 border border-slate-300 bg-white rounded-lg text-sm text-slate-600 hover:bg-slate-50">Search</button>
        @if ($q !== '')
            <a href="{{ route('admin.categories.index') }}" class="px-2 py-2 text-sm text-slate-500 hover:text-slate-700">Clear</a>
        @endif
    </form>

    <form method="POST" action="{{ route('admin.categories.store') }}" class="flex gap-2 ml-auto">
        @csrf
        <label for="new-category" class="sr-only">New category name</label>
        <input id="new-category" type="text" name="name" required maxlength="60" placeholder="New category, e.g. Roofing"
               class="w-64 px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
        <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Add Category</button>
    </form>
</div>

<div class="grid grid-cols-1 lg:grid-cols-[19rem_minmax(0,1fr)] gap-4 items-start">

    {{-- The list. --}}
    <nav class="bg-white rounded-xl border border-slate-200 overflow-hidden" aria-label="Categories">
        <p class="px-4 py-2.5 border-b border-slate-100 text-xs text-slate-500">
            @if ($q === '')
                {{ $count($categories->count(), 'category', 'categories') }}
            @else
                {{ $listed->count() }} of {{ $categories->count() }} match &ldquo;{{ $q }}&rdquo;
            @endif
        </p>

        @forelse ($listed as $category)
            @php $open = $selected && $selected->id === $category->id; @endphp
            <a href="{{ route('admin.categories.index', $keep(['category' => $category->id])) }}"
               @if ($open) aria-current="true" @endif
               class="block px-4 py-3 border-b border-slate-100 last:border-b-0 {{ $open ? 'bg-blue-50' : 'hover:bg-slate-50' }}">
                <span class="flex items-center gap-2 min-w-0">
                    <span class="truncate text-sm font-medium {{ $open ? 'text-blue-700' : ($category->is_active ? 'text-slate-800' : 'text-slate-500') }}">
                        {{ $category->name }}
                    </span>
                    @unless ($category->is_active)
                        <span class="shrink-0 px-1.5 py-px rounded text-[11px] bg-slate-100 text-slate-500">Hidden</span>
                    @endunless
                    @if ($category->is_custom)
                        <span class="shrink-0 px-1.5 py-px rounded text-[11px] border border-slate-200 text-slate-500">User-added</span>
                    @endif
                </span>
                <span class="block mt-0.5 text-xs text-slate-500 tabular-nums">
                    {{ $count($workersByCategory[$category->id] ?? 0, 'worker') }}
                    &middot; {{ $count($category->jobs_count, 'job') }}
                    &middot; {{ $count($category->skills_count, 'skill') }}
                </span>
            </a>
        @empty
            <p class="px-4 py-10 text-sm text-slate-500 text-center">
                No category or skill matches &ldquo;{{ $q }}&rdquo;.
            </p>
        @endforelse
    </nav>

    {{-- The open category. --}}
    @if ($selected)
        @php
            $workers = $workersByCategory[$selected->id] ?? 0;
        @endphp
        <section class="bg-white rounded-xl border border-slate-200" aria-labelledby="open-category">
            <header class="px-5 py-4 border-b border-slate-100">
                <div class="flex flex-wrap items-center gap-2">
                    <h2 id="open-category" class="text-base font-semibold text-slate-800">{{ $selected->name }}</h2>
                    @unless ($selected->is_active)
                        {{-- What the flag does: the app's category list only
                             returns active rows. --}}
                        <span class="badge-suspended px-2 py-0.5 rounded-full text-xs">Hidden from the app</span>
                    @endunless
                    @if ($selected->is_custom)
                        {{-- Neutral: nothing is waiting on a decision, a
                             worker simply typed this name. --}}
                        <span class="px-2 py-0.5 rounded-full text-xs bg-slate-100 text-slate-600">
                            Added by {{ $selected->creator?->name ?? 'a user' }}
                        </span>
                    @endif
                </div>
                <p class="mt-1 text-sm text-slate-500 tabular-nums">
                    {{ $count($workers, 'worker') }},
                    {{ $count($selected->jobs_count, 'job') }} ({{ $selected->open_jobs_count }} open),
                    {{ $count($selected->skills_count, 'skill') }}
                </p>
            </header>

            {{-- Name. --}}
            <form method="POST" action="{{ route('admin.categories.update', $selected) }}" class="px-5 py-4 border-b border-slate-100">
                @csrf
                <label for="category-name" class="block text-xs font-semibold text-slate-700 mb-1.5">Name</label>
                <div class="flex gap-2">
                    <input id="category-name" type="text" name="name" value="{{ $selected->name }}" required maxlength="60"
                           class="w-80 max-w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
                    <button class="px-4 py-2 border border-slate-300 rounded-lg text-sm text-slate-700 hover:bg-slate-50">Save Name</button>
                </div>
            </form>

            {{-- Skills. --}}
            <div class="px-5 py-4 border-b border-slate-100">
                <h3 class="text-sm font-semibold text-slate-700">Skills</h3>
                <p class="text-xs text-slate-500 mt-0.5">
                    What workers in this trade list and jobs ask for. A skill somebody uses can be renamed, not deleted.
                </p>

                @if ($selected->skills->isEmpty())
                    <p class="mt-3 text-sm text-slate-500">
                        No skills yet. Workers who pick {{ $selected->name }} will have nothing to choose from.
                    </p>
                @else
                    <table class="w-full text-sm mt-3">
                        <thead>
                            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                                <th class="py-2 pr-3 font-medium">Skill</th>
                                <th class="py-2 px-3 font-medium text-right">Workers</th>
                                <th class="py-2 px-3 font-medium text-right">Jobs</th>
                                <th class="py-2 pl-3"><span class="sr-only">Actions</span></th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-100">
                            @foreach ($selected->skills as $skill)
                                @php
                                    $skillWorkers = $workersBySkill[$skill->id] ?? 0;
                                    $skillJobs = $jobsBySkill[$skill->id] ?? 0;
                                    $matchesSearch = $q !== '' && str_contains(mb_strtolower($skill->name), mb_strtolower($q));
                                @endphp
                                <tr class="{{ $matchesSearch ? 'bg-blue-50/60' : '' }}">
                                    <td class="py-1.5 pr-3">
                                        <form id="skill-{{ $skill->id }}" method="POST" action="{{ route('admin.skills.update', $skill) }}">
                                            @csrf
                                            <label for="skill-name-{{ $skill->id }}" class="sr-only">Skill name</label>
                                            <input id="skill-name-{{ $skill->id }}" type="text" name="name" value="{{ $skill->name }}" required maxlength="60"
                                                   class="w-full max-w-xs px-2 py-1 bg-transparent border border-transparent hover:border-slate-200 focus:border-slate-300 focus:bg-white rounded text-sm">
                                        </form>
                                        @if ($skill->source === 'system')
                                            <span class="ml-2 text-[11px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">Added by System</span>
                                        @endif
                                    </td>
                                    <td class="py-1.5 px-3 text-right tabular-nums text-slate-600">{{ $skillWorkers }}</td>
                                    <td class="py-1.5 px-3 text-right tabular-nums text-slate-600">{{ $skillJobs }}</td>
                                    <td class="py-1.5 pl-3 text-right whitespace-nowrap">
                                        <button form="skill-{{ $skill->id }}" class="text-xs font-medium text-blue-600 hover:text-blue-700">Save</button>
                                        @if ($canDestroy && $skillWorkers === 0 && $skillJobs === 0)
                                            {{-- Only when nothing points at it, so the
                                                 button is absent rather than disabled. --}}
                                            <form method="POST" action="{{ route('admin.skills.destroy', $skill) }}" class="inline"
                                                  onsubmit="return confirm('Delete the skill {{ addslashes($skill->name) }}? Nothing is using it.')">
                                                @csrf
                                                <button class="ml-3 text-xs font-medium text-slate-500 hover:text-red-600">Delete</button>
                                            </form>
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                @endif

                <form method="POST" action="{{ route('admin.categories.skills.store', $selected) }}" class="flex gap-2 mt-3">
                    @csrf
                    <label for="new-skill" class="sr-only">New skill</label>
                    <input id="new-skill" type="text" name="name" required maxlength="60" placeholder="New skill, e.g. Cabinet making"
                           class="w-80 max-w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
                    <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Add Skill</button>
                </form>
            </div>

            @if ($canDestroy)
            {{-- Shown or hidden: reversible, and it says what it does. --}}
            <form method="POST" action="{{ route('admin.categories.toggle', $selected) }}" class="px-5 py-4 border-b border-slate-100 flex flex-wrap items-center gap-3">
                @csrf
                <button class="px-3 py-2 rounded-lg text-sm font-medium {{ $selected->is_active ? 'border border-slate-300 text-slate-700 hover:bg-slate-50' : 'bg-green-600 text-white hover:bg-green-700' }}">
                    {{ $selected->is_active ? 'Hide from the app' : 'Show in the app' }}
                </button>
                <span class="text-xs text-slate-500 flex-1 min-w-[14rem]">
                    {{ $selected->is_active
                        ? 'Workers and employers can pick this category. Hiding it leaves existing jobs and profiles alone.'
                        : 'Nobody can pick this category right now. Existing jobs and profiles still use it.' }}
                </span>
            </form>

            {{-- Merge: deletes this category, so it is folded away and asks first. --}}
            <details class="px-5 py-4 group">
                <summary class="text-sm font-medium text-red-600 cursor-pointer select-none">
                    Merge {{ $selected->name }} into another category
                </summary>
                <form method="POST" action="{{ route('admin.categories.merge', $selected) }}" class="mt-3 space-y-2"
                      onsubmit="return confirm('Move every job, worker and skill under {{ addslashes($selected->name) }} into ' + this.into.options[this.into.selectedIndex].text + ', then delete {{ addslashes($selected->name) }}? This cannot be undone.')">
                    @csrf
                    <p class="text-xs text-slate-500">
                        Every job, worker and skill under {{ $selected->name }} moves to the category you choose, and
                        {{ $selected->name }} is deleted. Use it for a duplicate, such as a user-added
                        &ldquo;Plumbing Services&rdquo; beside &ldquo;Plumbing&rdquo;.
                    </p>
                    <div class="flex flex-wrap items-center gap-2">
                        <label for="merge-into" class="sr-only">Merge into</label>
                        <select id="merge-into" name="into" required class="px-2 py-2 border border-slate-300 rounded-lg text-sm">
                            <option value="">Choose a category</option>
                            @foreach ($categories->where('id', '!=', $selected->id) as $other)
                                <option value="{{ $other->id }}">{{ $other->name }}</option>
                            @endforeach
                        </select>
                        <button class="px-3 py-2 border border-red-300 text-red-600 rounded-lg text-sm font-medium hover:bg-red-50">
                            Merge and Delete
                        </button>
                    </div>
                </form>
            </details>
            @endif
        </section>
    @else
        <section class="bg-white rounded-xl border border-slate-200 px-5 py-14 text-center">
            <p class="text-sm font-medium text-slate-700">
                {{ $categories->isEmpty() ? 'No categories yet' : 'Nothing to open' }}
            </p>
            <p class="text-sm text-slate-500 mt-1">
                {{ $categories->isEmpty()
                    ? 'Add the first trade above. Workers pick from these, and jobs are posted under them.'
                    : 'Change or clear the search to see categories again.' }}
            </p>
        </section>
    @endif
</div>

{{-- Synonyms: they pair names across categories, so they belong to none. --}}
<section class="mt-6 bg-white rounded-xl border border-slate-200" aria-labelledby="synonyms">
    <div class="px-5 py-4 border-b border-slate-100">
        <h2 id="synonyms" class="text-sm font-semibold text-slate-700">Words That Mean the Same</h2>
        <p class="text-xs text-slate-500 mt-0.5">
            Two names for the same work, such as Screen Replacement and LCD Replacement. Once linked, jobs and workers
            using either name match each other.
        </p>
        <form method="POST" action="{{ route('admin.skill-aliases.store') }}" class="flex flex-wrap gap-2 mt-3">
            @csrf
            <label for="term-a" class="sr-only">First name</label>
            <input id="term-a" type="text" name="term_a" required maxlength="120" placeholder="e.g. Screen Replacement"
                   class="flex-1 min-w-[10rem] max-w-xs px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <span class="self-center text-sm text-slate-400" aria-hidden="true">=</span>
            <label for="term-b" class="sr-only">Second name</label>
            <input id="term-b" type="text" name="term_b" required maxlength="120" placeholder="e.g. LCD Replacement"
                   class="flex-1 min-w-[10rem] max-w-xs px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Link</button>
        </form>
    </div>

    @if ($aliases->isEmpty())
        <p class="px-5 py-6 text-sm text-slate-500">
            {{ $q === '' ? 'No synonyms linked yet.' : 'No synonym matches “' . $q . '”.' }}
        </p>
    @else
        <ul class="divide-y divide-slate-100">
            @foreach ($aliases as $alias)
                <li class="px-5 py-2.5 flex items-center justify-between gap-3 text-sm">
                    <span class="text-slate-700">
                        {{ $alias->term_a }} <span class="text-slate-400">=</span> {{ $alias->term_b }}
                        @if ($alias->creator)
                            <span class="ml-2 text-xs text-slate-400">linked by {{ $alias->creator->name }}</span>
                        @endif
                    </span>
                    <form method="POST" action="{{ route('admin.skill-aliases.destroy', $alias) }}">
                        @csrf
                        <button class="text-xs text-slate-500 hover:text-red-600">Unlink</button>
                    </form>
                </li>
            @endforeach
        </ul>
    @endif
</section>

{{-- The System's Gemini checks: how many, and what each one did. --}}
<section class="mt-6 bg-white rounded-xl border border-slate-200" aria-labelledby="system-log">
    <div class="px-5 py-4 border-b border-slate-200">
        <h2 id="system-log" class="text-sm font-semibold text-slate-700">System Log</h2>
    </div>
    <div class="grid grid-cols-2 sm:grid-cols-5 divide-x divide-slate-200 border-b border-slate-200">
        @foreach ([['Requests Today', $linkUsage['today']], ['Requests This Month', $linkUsage['month']],
                   ['Failed Today', $linkUsage['failed']], ['Words Linked', $linkUsage['linked']],
                   ['Skills Added by System', $linkUsage['created']]] as [$label, $value])
            <div class="px-5 py-3">
                <p class="text-xs text-slate-500">{{ $label }}</p>
                <p class="mt-0.5 text-lg font-semibold text-slate-900 tabular-nums">{{ number_format($value) }}</p>
            </div>
        @endforeach
    </div>
    @if ($linkLog->isEmpty())
        <p class="px-5 py-6 text-sm text-slate-500">None.</p>
    @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs text-slate-500 border-b border-slate-200">
                        <th class="py-2.5 px-5 font-medium">Time</th>
                        <th class="py-2.5 px-5 font-medium">Word</th>
                        <th class="py-2.5 px-5 font-medium">Result</th>
                        <th class="py-2.5 px-5 font-medium">Skills</th>
                        <th class="py-2.5 px-5 font-medium text-right">Took</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($linkLog as $entry)
                        <tr class="border-b border-slate-200 last:border-0">
                            <td class="py-2 px-5 text-slate-500 whitespace-nowrap">{{ $entry->created_at->timezone('Asia/Manila')->format('M j, g:i A') }}</td>
                            <td class="py-2 px-5 text-slate-800">{{ $entry->term }}</td>
                            <td class="py-2 px-5 whitespace-nowrap {{ $entry->outcome === 'failed' ? 'text-red-700' : 'text-slate-700' }}">
                                {{ ['linked' => 'Linked', 'created' => 'New Skill', 'none' => 'Not a Skill', 'failed' => 'Failed'][$entry->outcome] ?? ucfirst($entry->outcome) }}
                            </td>
                            <td class="py-2 px-5 text-slate-600">{{ $entry->skills ?? $entry->error ?? '' }}</td>
                            <td class="py-2 px-5 text-right text-slate-500 tabular-nums">{{ number_format($entry->ms / 1000, 1) }}s</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>

{{-- What people typed, and the skills the System linked it to. --}}
<section class="mt-6 bg-white rounded-xl border border-slate-200" aria-labelledby="linked-words">
    <div class="px-5 py-4 border-b border-slate-200">
        <h2 id="linked-words" class="text-sm font-semibold text-slate-700">Linked Words</h2>
    </div>
    @if ($links->isEmpty())
        <p class="px-5 py-6 text-sm text-slate-500">None.</p>
    @else
        <ul class="divide-y divide-slate-200">
            @foreach ($links as $term => $rows)
                @php $skills = $rows->pluck('skill.name')->filter(); @endphp
                <li class="px-5 py-2.5 flex items-center justify-between gap-3 text-sm">
                    <span class="text-slate-700">
                        {{ $term }} <span class="text-slate-400">→</span>
                        {{ $skills->isEmpty() ? 'Not a Skill' : $skills->join(', ') }}
                        <span class="ml-2 text-xs text-slate-500">Used by {{ $usedBy[$term] ?? 0 }}</span>
                    </span>
                    @if ($skills->isNotEmpty())
                        <form method="POST" action="{{ route('admin.skill-links.unlink') }}">
                            @csrf
                            <input type="hidden" name="term" value="{{ $term }}">
                            <button class="text-xs text-slate-500 hover:text-red-600">Unlink</button>
                        </form>
                    @endif
                </li>
            @endforeach
        </ul>
    @endif
</section>
@endsection
