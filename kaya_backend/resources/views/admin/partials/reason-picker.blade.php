{{--
    A reason, chosen from a list. The chosen line is what is saved and
    what the person reads; there is no text box beside it to retype it.

    Takes: $reasons (list of strings), and optionally $name, $placeholder.
--}}
<select name="{{ $name ?? 'reason' }}" required aria-label="{{ $placeholder ?? 'Reason' }}"
        class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white mb-2">
    @foreach ($reasons as $reason)
        <option value="{{ $reason }}" @selected($loop->first)>{{ $reason }}</option>
    @endforeach
</select>
