{{--
    A person's photo, or the first letter of their name when they have none.

    The users list and the verification page drew the letter for everybody,
    so nobody on them ever had a face. Takes $user and $class (size and text).
--}}
@php($photo = $user?->resolvedAvatarUrl())
<div class="{{ $class }} rounded-full bg-slate-200 overflow-hidden flex-shrink-0 flex items-center justify-center font-semibold text-slate-600">
    @if ($photo)
        <img src="{{ $photo }}" alt="" loading="lazy" class="w-full h-full object-cover">
    @else
        {{ mb_strtoupper(mb_substr($user?->name ?? '?', 0, 1)) }}
    @endif
</div>
