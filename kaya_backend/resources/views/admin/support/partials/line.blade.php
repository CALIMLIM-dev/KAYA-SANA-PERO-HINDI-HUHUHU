{{-- One line of a support chat: an event as a divider, a message as a bubble. --}}
@if ($message->isEvent())
    <p class="text-center text-xs text-slate-400 py-1">{{ $message->body }}</p>
@else
    @php $bot = (bool) $message->is_assistant; @endphp
    <div class="flex {{ $message->from_admin ? 'justify-end' : 'justify-start' }}">
        <div class="max-w-[75%] px-4 py-2.5 rounded-2xl {{ $bot ? 'bg-blue-50 text-slate-800 border border-blue-100' : ($message->from_admin ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-800') }}">
            <p class="text-sm whitespace-pre-line">{{ $message->body }}</p>
            <p class="text-[11px] mt-1 {{ $bot ? 'text-slate-500' : ($message->from_admin ? 'text-blue-200' : 'text-slate-400') }}">
                {{ $message->panelName($thread->user?->name) }}
                &middot; {{ $message->created_at->format('M j, g:ia') }}
            </p>
        </div>
    </div>
@endif