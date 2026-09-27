@extends('admin.layouts.app')
@section('page-title', 'Support')

{{-- A page that is only a conversation: refreshing it loses nothing,
     so typing a reply must not stop it updating. --}}
@push('body-attributes') data-live @endpush

@section('content')
<div class="max-w-3xl space-y-4">
    <div class="bg-white rounded-xl border border-slate-200 p-5 flex items-center gap-3">
        <div class="flex-1 min-w-0">
            <p class="font-medium text-slate-800">{{ $thread->user?->name ?? 'Deleted account' }}</p>
            <p class="text-sm text-slate-500">{{ $thread->user?->email }}</p>
        </div>
        @if ($thread->user)
            <a href="{{ route('admin.users.show', $thread->user) }}"
               class="px-3 py-2 border border-slate-300 text-slate-600 rounded-lg text-sm hover:bg-slate-50">Open Account</a>
        @endif
    </div>

    <div id="thread" data-since="{{ $thread->messages->max('id') ?? 0 }}"
         data-url="{{ route('admin.support.since', $thread) }}"
         class="bg-white rounded-xl border border-slate-200 p-5 space-y-3">
        @forelse ($thread->messages as $message)
            <div class="flex {{ $message->from_admin ? 'justify-end' : 'justify-start' }}">
                <div class="max-w-[75%] px-4 py-2.5 rounded-2xl {{ $message->from_admin ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-800' }}">
                    <p class="text-sm whitespace-pre-line">{{ $message->body }}</p>
                    <p class="text-[11px] mt-1 {{ $message->from_admin ? 'text-blue-200' : 'text-slate-400' }}">
                        {{ $message->from_admin ? ($message->sender?->name ?? 'KAYA') : ($thread->user?->name ?? 'Them') }}
                        &middot; {{ $message->created_at->format('M j, g:ia') }}
                    </p>
                </div>
            </div>
        @empty
            <p class="text-sm text-slate-400 text-center py-4">Nothing said yet.</p>
        @endforelse
    </div>

    <form method="POST" action="{{ route('admin.support.reply', $thread) }}"
          class="bg-white rounded-xl border border-slate-200 p-5 space-y-3">
        @csrf
        <textarea name="body" rows="3" maxlength="2000" required
                  class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                         focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Write a reply. They get a notification."></textarea>
        <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Send Reply</button>
    </form>
</div>
@endsection

@push('scripts')
<script>
/*
    New lines appear without the page moving.

    The panel's own pulse reloads the whole page when data changes, which on
    a conversation loses the scroll position and empties a half typed reply
    for the sake of one new message. This asks only for what it has not seen
    and appends it, every three seconds, and stops while the tab is hidden.
*/
(function () {
    var thread = document.getElementById('thread');
    if (!thread) return;

    var since = parseInt(thread.dataset.since || '0', 10);
    var url = thread.dataset.url;
    var timer = null;

    function bubble(m) {
        var row = document.createElement('div');
        row.className = 'flex ' + (m.from_admin ? 'justify-end' : 'justify-start');

        var box = document.createElement('div');
        box.className = 'max-w-[75%] px-4 py-2.5 rounded-2xl '
            + (m.from_admin ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-800');

        var body = document.createElement('p');
        body.className = 'text-sm whitespace-pre-line';
        body.textContent = m.body;

        var meta = document.createElement('p');
        meta.className = 'text-[11px] mt-1 ' + (m.from_admin ? 'text-blue-200' : 'text-slate-400');
        meta.textContent = m.who + ' · ' + m.at;

        box.appendChild(body);
        box.appendChild(meta);
        row.appendChild(box);

        return row;
    }

    function poll() {
        fetch(url + '?after=' + since, { headers: { 'Accept': 'application/json' } })
            .then(function (r) { return r.ok ? r.json() : null; })
            .then(function (data) {
                if (!data || !data.messages || !data.messages.length) return;

                var empty = thread.querySelector('.text-slate-400');
                if (empty && empty.textContent.indexOf('Nothing said yet') !== -1) {
                    empty.remove();
                }

                data.messages.forEach(function (m) {
                    thread.appendChild(bubble(m));
                    since = Math.max(since, m.id);
                });

                thread.scrollIntoView({ block: 'end' });
            })
            .catch(function () { /* the next tick tries again */ });
    }

    function start() {
        if (timer) return;
        timer = setInterval(poll, 3000);
    }

    function stop() {
        clearInterval(timer);
        timer = null;
    }

    document.addEventListener('visibilitychange', function () {
        document.hidden ? stop() : (poll(), start());
    });

    start();
})();
</script>
@endpush
