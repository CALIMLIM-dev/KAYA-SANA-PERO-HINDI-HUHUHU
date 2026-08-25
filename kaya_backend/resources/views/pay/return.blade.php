<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Payment received</title>
    <style>
        body { margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
               background:#F7F8F6; color:#16202B; font-family:system-ui,-apple-system,"Segoe UI",sans-serif; }
        .card { max-width:420px; padding:40px 32px; text-align:center; }
        h1 { font-size:22px; margin:0 0 12px; }
        p { color:#5C6B72; line-height:1.6; margin:0 0 10px; }
        .small { font-size:14px; color:#8A9A95; margin-top:20px; }
    </style>
</head>
<body>
    {{--
        This page grants nothing.

        It is a full stop for a browser tab, not a trust boundary. The credits
        are granted by the webhook, or by the reconciler if the webhook never
        arrives — both server side, both verified with PayMongo. Anyone can open
        this URL directly without paying, which is exactly why it must not be
        able to give anything away.
    --}}
    <div class="card">
        <h1>Payment received</h1>
        <p>You can close this page and return to KAYA.</p>
        <p>Your balance updates within a few seconds.</p>
        <p class="small">If it has not appeared after a minute, pull down to refresh the wallet.</p>
    </div>
</body>
</html>
