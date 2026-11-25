{{--
    The one look every KAYA email has: 600px wide (the width mail apps are
    built for), edge to edge on a phone where the mail app already adds its
    own margins, KAYA's blue, the logo, the code large.
    Inline styles only - Gmail drops a <style> block in many places.
--}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light">
    <title>@yield('title')</title>
</head>
<body style="margin:0; padding:0; background:#F3F5F9; font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; -webkit-text-size-adjust:100%;">
    {{-- The line a mail app shows beside the subject. The blanks after it
         keep the rest of the email, and the code, out of that line. --}}
    <div style="display:none; max-height:0; overflow:hidden; opacity:0;">@yield('preheader'){!! str_repeat('&#847;&zwnj;&nbsp;', 120) !!}</div>

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F5F9;">
        <tr>
            <td align="center" style="padding:16px 0;">
                <table role="presentation" width="600" cellpadding="0" cellspacing="0"
                       style="width:100%; max-width:600px; background:#FFFFFF; border:1px solid #E6E9F0; border-radius:12px; overflow:hidden;">
                    <tr><td style="height:6px; background:#3D5CFF; font-size:0; line-height:0;">&nbsp;</td></tr>
                    <tr>
                        <td style="padding:24px 20px 8px;">
                            <table role="presentation" cellpadding="0" cellspacing="0">
                                <tr>
                                    <td style="vertical-align:middle;">
                                        <img src="{{ rtrim(config('app.url'), '/') }}/images/kaya-mail.png" width="44" height="44" alt="KAYA"
                                             style="display:block; border:0; width:44px; height:44px;">
                                    </td>
                                    <td style="vertical-align:middle; padding-left:10px; font-size:24px; font-weight:800; color:#3D5CFF; letter-spacing:1px;">KAYA</td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:16px 20px 28px;">
                            @yield('content')
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:18px 20px; background:#F8F9FC; border-top:1px solid #E6E9F0; font-size:12px; line-height:1.6; color:#6B7280;">
                            KAYA - find trusted work and workers near you.<br>
                            This is an automatic email. Please do not reply to it.
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
