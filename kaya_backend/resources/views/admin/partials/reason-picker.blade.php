{{--
    A reason, chosen rather than typed.

    Every moderation action here asks why, and every one of them used a bare
    text box. That means the same refusal is worded six different ways by the
    same person in a week, and the wording is what the user reads - so the
    answer they get for a blocked post depends on how tired somebody was.

    The box is written already: it starts on the first reason and changes
    with the list, and it can be edited for anything the list does not say.
    Nobody has to type.

    Takes: $reasons (list of strings), and optionally $name, $placeholder.
--}}
@php
    $field = $name ?? 'reason';
    $id = $field . '_' . uniqid();
@endphp

<div class="reason-picker" data-reason-picker>
    <select data-reason-select aria-label="Reason"
            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
        @foreach ($reasons as $reason)
            <option value="{{ $reason }}" @selected($loop->first)>{{ $reason }}</option>
        @endforeach
    </select>

    <input type="text" name="{{ $field }}" id="{{ $id }}" required maxlength="255"
           data-reason-input value="{{ $reasons[0] ?? '' }}"
           aria-label="{{ $placeholder ?? 'Reason' }}"
           class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
</div>
