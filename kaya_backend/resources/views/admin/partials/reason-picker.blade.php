{{--
    A reason, chosen rather than typed.

    Every moderation action here asks why, and every one of them used a bare
    text box. That means the same refusal is worded six different ways by the
    same person in a week, and the wording is what the user reads - so the
    answer they get for a blocked post depends on how tired somebody was.

    The list is the common cases; "Other" opens the box for the rest, because
    a fixed list that cannot express the actual reason just gets the nearest
    wrong one picked.

    Takes: $reasons (list of strings), and optionally $name, $placeholder.
--}}
@php
    $field = $name ?? 'reason';
    $id = $field . '_' . uniqid();
@endphp

<div class="reason-picker" data-reason-picker>
    <select data-reason-select
            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
        <option value="" selected disabled>Choose a reason...</option>
        @foreach ($reasons as $reason)
            <option value="{{ $reason }}">{{ $reason }}</option>
        @endforeach
        <option value="__other">Other...</option>
    </select>

    <input type="text" name="{{ $field }}" id="{{ $id }}" required maxlength="255"
           data-reason-input
           placeholder="{{ $placeholder ?? 'Reason' }}"
           class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2 hidden">
</div>
