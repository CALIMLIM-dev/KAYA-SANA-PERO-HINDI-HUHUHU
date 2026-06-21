<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Admin Login · KAYA</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>body{font-family:'Inter',sans-serif;}</style>
</head>
<body class="bg-slate-100 min-h-screen flex items-center justify-center">
    <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-8 w-full max-w-sm">
        <div class="text-center mb-6">
            <span class="text-2xl font-bold text-blue-600">KAYA</span>
            <p class="text-sm text-slate-400">Admin Panel</p>
        </div>

        @if ($errors->any())
            <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">
                {{ $errors->first() }}
            </div>
        @endif

        <form method="POST" action="{{ route('admin.login') }}" class="space-y-4">
            @csrf
            <div>
                <label class="text-sm font-medium text-slate-600">Email</label>
                <input type="email" name="email" required value="{{ old('email') }}"
                       class="mt-1 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <div>
                <label class="text-sm font-medium text-slate-600">Password</label>
                <input type="password" name="password" required
                       class="mt-1 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <button type="submit"
                    class="w-full bg-blue-600 text-white rounded-lg py-2.5 text-sm font-semibold hover:bg-blue-700">
                Sign In
            </button>
        </form>
    </div>
</body>
</html>
