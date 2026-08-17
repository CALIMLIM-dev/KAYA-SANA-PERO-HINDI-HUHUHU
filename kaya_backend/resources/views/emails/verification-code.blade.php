{{-- Plain and short on purpose: verification mail that looks like marketing
     gets filtered, and the only thing the reader needs is the code. --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KAYA verification code</title>
</head>
<body style="margin:0; padding:0; background:#f4f6f9; font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f9; padding:32px 16px;">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                       style="max-width:440px; background:#ffffff; border-radius:14px; padding:32px;">
                    <tr>
                        <td>
                            <p style="margin:0 0 4px; font-size:20px; font-weight:700; color:#0f172a;">KAYA</p>
                            <p style="margin:0 0 24px; font-size:13px; color:#64748b;">
                                Verify your {{ $subjectOfVerification }}
                            </p>

                            <p style="margin:0 0 16px; font-size:14px; color:#0f172a;">
                                Hi {{ $userName }},
                            </p>
                            <p style="margin:0 0 24px; font-size:14px; line-height:1.6; color:#334155;">
                                Enter this code in the app to confirm your {{ $subjectOfVerification }}.
                            </p>

                            <div style="text-align:center; margin:0 0 24px;">
                                <span style="display:inline-block; font-size:32px; font-weight:700; letter-spacing:8px;
                                             color:#0f172a; background:#f1f5f9; border-radius:10px; padding:16px 24px;">
                                    {{ $code }}
                                </span>
                            </div>

                            <p style="margin:0 0 8px; font-size:13px; line-height:1.6; color:#64748b;">
                                The code expires in 10 minutes.
                            </p>
                            <p style="margin:0; font-size:13px; line-height:1.6; color:#64748b;">
                                If you did not ask for this, you can ignore this email — nothing has changed
                                on your account.
                            </p>
                        </td>
                    </tr>
                </table>
                <p style="margin:16px 0 0; font-size:11px; color:#94a3b8;">
                    Sent by KAYA. Please do not reply to this message.
                </p>
            </td>
        </tr>
    </table>
</body>
</html>
