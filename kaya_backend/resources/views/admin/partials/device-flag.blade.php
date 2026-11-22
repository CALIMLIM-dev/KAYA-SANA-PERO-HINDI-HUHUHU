@if ($user && \App\Support\DeviceIds::sharesBannedDevice($user->id))
    <span class="inline-block text-xs px-2 py-0.5 rounded-full bg-red-50 text-red-700 font-medium">Same device as a banned account</span>
@endif
