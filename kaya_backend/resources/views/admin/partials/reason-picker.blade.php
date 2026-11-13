{{--
    A reason, chosen from a list. The chosen line is what is saved and what
    the person reads. Other opens a box for anything the list does not cover;
    the box is the only place a reason is typed.

    Starts on "Choose a reason", never on the first reason: a pre-picked one
    was sent with whatever happened to be on top, and the form's button stays
    off until a reason is chosen.

    Takes: $reasons (list of strings), and optionally $name, $placeholder.
--}}
@php($field = $name ?? 'reason')
<div data-reason-picker>
    <select name="{{ $field }}" required aria-label="{{ $placeholder ?? 'Reason' }}" data-reason-select
            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white mb-2">
        <option value="" disabled selected>Choose a reason</option>
        @foreach ($reasons as $reason)
            <option value="{{ $reason }}">{{ $reason }}</option>
        @endforeach
        <option value="__other">Other</option>
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
    var form = picker.closest('form');
    var button = form ? form.querySelector('button:not([type="button"])') : null;
    var name = select.name;

    var sync = function () {
        var typing = select.value === '__other';
        var ready = typing ? other.value.trim() !== '' : select.value !== '';
        if (button) {
            button.disabled = !ready;
            button.style.opacity = ready ? '' : '0.5';
            button.style.cursor = ready ? '' : 'not-allowed';
        }
    };

    select.addEventListener('change', function () {
        var typing = select.value === '__other';
        // Only one of the two is sent: the choice, or the typed reason.
        select.name = typing ? '' : name;
        select.required = !typing;
        other.disabled = !typing;
        other.hidden = !typing;
        other.required = typing;
        if (typing) other.focus();
        sync();
    });
    other.addEventListener('input', sync);
    sync();
})();
</script>
