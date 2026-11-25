{{-- The code itself: large, spaced, easy to read and to copy. What it is for
     and how long it lasts come first, so a mail app's preview ends before it. --}}
<p style="margin:0 0 6px; font-size:14px; line-height:1.6; color:#374151;">It expires in <strong>{{ $minutes }} minutes</strong>. Never share it. KAYA will never ask you for this code.</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:14px 0 24px;">
    <tr>
        <td align="center" style="background:#EEF1FF; border-radius:12px; padding:22px 12px;">
            <span style="font-size:38px; font-weight:800; letter-spacing:8px; padding-left:8px; color:#3D5CFF; font-family:'SFMono-Regular',Consolas,'Courier New',monospace;">{{ $code }}</span>
        </td>
    </tr>
</table>
<p style="margin:0; padding-top:20px; border-top:1px solid #E6E9F0; font-size:13px; line-height:1.6; color:#6B7280;">
    Did not ask for this? You can ignore this email. Nothing on your account has changed.
</p>
