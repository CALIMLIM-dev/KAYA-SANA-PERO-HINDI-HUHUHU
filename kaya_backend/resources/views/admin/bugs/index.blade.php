@extends('admin.layouts.app')
@section('page-title', 'Bug Reports')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex gap-1">
        @foreach (['new' => 'New', 'fixed' => 'Fixed'] as $key => $label)
            <a href="{{ route('admin.bugs.index', ['show' => $key]) }}"
               class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                {{ $label }} <span class="text-xs text-slate-400 tabular-nums">{{ $counts[$key] ?? 0 }}</span>
            </a>
        @endforeach
    </div>

    <ul class="divide-y divide-slate-100">
        @forelse ($reports as $bug)
            <li class="p-5 flex gap-5">
                <div class="flex-1 min-w-0 space-y-1">
                    <p class="font-medium text-slate-800">{{ $bug->issueLabel() }} <span class="text-slate-400 font-normal">· {{ $bug->screenLabel() }}</span></p>
                    @if ($bug->details)
                        <p class="text-sm text-slate-700 whitespace-pre-line">{{ $bug->details }}</p>
                    @endif
                    <p class="text-xs text-slate-500">
                        {{ $bug->user?->name ?? 'Deleted account' }}
                        · {{ $bug->app_version ? 'KAYA ' . $bug->app_version : 'Version unknown' }}
                        @if ($bug->device) · {{ $bug->device }} @endif
                        · {{ $bug->created_at->timezone('Asia/Manila')->format('M j, g:i A') }}
                        @if ($bug->fixed_at) · Fixed {{ $bug->fixed_at->timezone('Asia/Manila')->format('M j') }} @endif
                    </p>
                    @foreach ($bug->server_error_ids ?? [] as $errorId)
                        @if ($error = $errors[$errorId] ?? null)
                            <p class="text-xs font-mono text-red-700 truncate">Server error: {{ class_basename($error->exception) }} · {{ $error->message }}</p>
                        @endif
                    @endforeach
                </div>
                @if ($bug->screenshot_path)
                    <a href="{{ route('admin.bugs.screenshot', $bug) }}" target="_blank" rel="noopener"
                       class="block w-20 h-36 rounded-lg overflow-hidden border border-slate-200 shrink-0">
                        <img src="{{ route('admin.bugs.screenshot', $bug) }}" alt="Screenshot" class="w-full h-full object-cover">
                    </a>
                @endif
                @if ($bug->status === 'new')
                    <form method="POST" action="{{ route('admin.bugs.fix', $bug) }}" class="shrink-0">
                        @csrf
                        <button class="px-3 py-2 border border-slate-300 text-slate-700 rounded-lg text-sm hover:bg-slate-50">Mark Fixed</button>
                    </form>
                @endif
            </li>
        @empty
            <li class="p-8 text-center text-sm text-slate-400">{{ $show === 'new' ? 'No new bug reports.' : 'Nothing marked fixed yet.' }}</li>
        @endforelse
    </ul>
    <div class="p-5">{{ $reports->links() }}</div>
</div>
@endsection