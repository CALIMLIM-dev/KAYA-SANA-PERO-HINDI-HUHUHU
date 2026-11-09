{{--
    The violation, chosen from a list: each option is the exact line the
    person will receive, and the penalty it means for them now shows under
    it. The same list on Reports and on a user's page, so the same finding
    costs the same wherever it is given.

    Takes: $penalties (code => "a 7-day suspension"), optionally $selected.
--}}
@php($pickerId = 'violation_' . uniqid())
<div data-violation-picker>
    <label for="{{ $pickerId }}" class="block text-xs font-semibold text-slate-600 mb-1.5">Violation</label>
    <select name="reason_code" id="{{ $pickerId }}" data-violation-select
            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
        <option value="" disabled @selected(! old('reason_code', $selected ?? null))>Choose a violation</option>
        @foreach (\App\Support\ModerationReasons::SEVERITIES as $sev => $groupLabel)
            <optgroup label="{{ $groupLabel }}">
                @foreach (collect(\App\Support\ModerationReasons::SUSPENSION)->where('severity', $sev) as $code => $reason)
                    <option value="{{ $code }}" data-penalty="{{ $penalties[$code] ?? '' }}"
                            @selected(old('reason_code', $selected ?? null) === $code)>{{ $reason['label'] }}: {{ $reason['description'] }}</option>
                @endforeach
            </optgroup>
        @endforeach
    </select>
    <p class="mt-2 text-xs text-slate-600 hidden" data-violation-penalty></p>
</div>
<script>
(function () {
    var picker = document.currentScript.previousElementSibling;
    var select = picker.querySelector('[data-violation-select]');
    var line = picker.querySelector('[data-violation-penalty]');
    var show = function () {
        var option = select.options[select.selectedIndex];
        var penalty = option && option.dataset.penalty;
        line.textContent = penalty ? 'Penalty: ' + penalty.charAt(0).toUpperCase() + penalty.slice(1) + '.' : '';
        line.classList.toggle('hidden', !penalty);
    };
    select.addEventListener('change', show);
    show();
})();
</script>
