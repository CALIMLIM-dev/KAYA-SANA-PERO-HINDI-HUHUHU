{{--
    Where an account's verification stands, said the same way on every page.

    The user pages showed "Pending" for every account that was not verified,
    including the ones that never sent anything, so a list of people who had
    never opened the verification screen read as a queue waiting on an admin.
    This reads User::verification_state, the value the app's own chip shows:
    verified, verified business, pending review (papers are waiting on an
    admin) or not verified.
--}}
@php
    [$label, $class] = match ($user->verification_state) {
        \App\Models\User::VERIFIED => ['Verified', 'badge-verified'],
        \App\Models\User::VERIFIED_BUSINESS => ['Verified business', 'badge-verified'],
        \App\Models\User::VERIFICATION_PENDING => ['Pending review', 'badge-pending'],
        default => ['Not verified', 'bg-slate-100 text-slate-600'],
    };
@endphp
<span class="{{ $class }} text-xs {{ $size ?? 'px-2 py-1' }} rounded-full">{{ $label }}</span>
