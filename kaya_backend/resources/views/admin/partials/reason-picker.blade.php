{{--
    A reason, chosen from a list. The chosen line is what is saved and what
    the person reads. Other opens a box for anything the list does not cover;
    the box is the only place a reason is typed.

    Takes: $reasons (list of strings), and optionally $name, $placeholder.
--}}
@php($field = $name ?? 'reason')
<div data-reason-picker>
    <select name="{{ $field }}" required aria-label="{{ $placeholder ?? 'Reason' }}" data-reason-select
            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white mb-2">
        @foreach ($reasons as $reason)
            <option value="{{ $reason }}" @selected($loop->first)>{{ $reason }}</option>
        @endforeach
        <option value="">Other</option>
    </select>
    <input type="text" name="{{ $field }}" maxlength="255" disabled hidden data-reason-other
           placeholder="Write the reason" aria-label="Other reason"
           class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm mb-2">
</div>
<script>
(function () {
    var picker = document.currentScript.previousElementSibling;
    var select = picker.querySelector('[data-reason-select]');
    var other = picker.querySelector('[data-reason-other]');
    var name = select.name;
    select.addEventListener('change', function () {
        var typing = select.value === '';
        // Only one of the two is sent: the choice, or the typed reason.
        select.name = typing ? '' : name;
        select.required = !typing;
        other.disabled = !typing;
        other.hidden = !typing;
        other.required = typing;
        if (typing) other.focus();
    });
})();
</script>
