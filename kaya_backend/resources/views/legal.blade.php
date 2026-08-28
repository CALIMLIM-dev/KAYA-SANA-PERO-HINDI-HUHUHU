<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title }} — KAYA</title>
    <style>
        :root { --ink:#1f2430; --muted:#5b6472; --line:#e6e8ec; --accent:#3d5afe; --bg:#f7f8fa; }
        * { box-sizing: border-box; }
        body {
            margin: 0; background: var(--bg); color: var(--ink);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6; -webkit-text-size-adjust: 100%;
        }
        .wrap { max-width: 760px; margin: 0 auto; padding: 32px 20px 64px; }
        header { border-bottom: 1px solid var(--line); padding-bottom: 20px; margin-bottom: 28px; }
        .brand { font-weight: 700; letter-spacing: .5px; color: var(--accent); font-size: 14px; }
        h1 { font-size: 26px; margin: 8px 0 4px; }
        .updated { color: var(--muted); font-size: 13px; }
        section { margin: 26px 0; }
        h2 { font-size: 17px; margin: 0 0 8px; }
        .num { color: var(--accent); font-weight: 700; margin-right: 6px; }
        p { margin: 0 0 12px; color: var(--ink); white-space: pre-line; }
        .other { margin-top: 40px; font-size: 14px; color: var(--muted); }
        .other a { color: var(--accent); text-decoration: none; }
        footer { margin-top: 48px; padding-top: 20px; border-top: 1px solid var(--line); color: var(--muted); font-size: 13px; }
    </style>
</head>
<body>
    <div class="wrap">
        <header>
            <div class="brand">KAYA</div>
            <h1>{{ $title }}</h1>
            <div class="updated">Last updated {{ $updated }}</div>
        </header>

        @foreach ($sections as $i => $s)
            <section>
                <h2><span class="num">{{ $i + 1 }}.</span>{{ $s['title'] }}</h2>
                <p>{{ $s['body'] }}</p>
            </section>
        @endforeach

        <div class="other">
            @if ($which === 'terms')
                Looking for our <a href="/privacy">Privacy Policy</a>?
            @else
                Looking for our <a href="/terms">Terms and Conditions</a>?
            @endif
        </div>

        <footer>
            KAYA — a Philippine job marketplace. For questions about this document, contact the KAYA team.
        </footer>
    </div>
</body>
</html>
