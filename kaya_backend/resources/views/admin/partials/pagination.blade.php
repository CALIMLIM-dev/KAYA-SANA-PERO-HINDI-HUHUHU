{{--
    The panel's own pager.

    Laravel's stock Tailwind pager carries dark: variants, and the Tailwind
    CDN switches those on from the browser's colour scheme, so on a machine
    set to dark mode the buttons came out slate on a white page.
--}}
@if ($paginator->hasPages())
    <nav class="flex items-center justify-between text-sm" aria-label="Pages">
        <p class="text-slate-500">
            {{ $paginator->firstItem() }} to {{ $paginator->lastItem() }} of {{ $paginator->total() }}
        </p>

        <div class="flex items-center gap-1">
            @if ($paginator->onFirstPage())
                <span class="px-3 py-1.5 rounded-lg border border-slate-200 text-slate-300">Previous</span>
            @else
                <a href="{{ $paginator->previousPageUrl() }}" rel="prev"
                   class="px-3 py-1.5 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50">Previous</a>
            @endif

            @foreach ($elements as $element)
                @if (is_string($element))
                    <span class="px-2 text-slate-400">{{ $element }}</span>
                @endif

                @if (is_array($element))
                    @foreach ($element as $page => $url)
                        @if ($page == $paginator->currentPage())
                            <span class="px-3 py-1.5 rounded-lg bg-blue-600 text-white font-medium">{{ $page }}</span>
                        @else
                            <a href="{{ $url }}" class="px-3 py-1.5 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50">{{ $page }}</a>
                        @endif
                    @endforeach
                @endif
            @endforeach

            @if ($paginator->hasMorePages())
                <a href="{{ $paginator->nextPageUrl() }}" rel="next"
                   class="px-3 py-1.5 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50">Next</a>
            @else
                <span class="px-3 py-1.5 rounded-lg border border-slate-200 text-slate-300">Next</span>
            @endif
        </div>
    </nav>
@endif
