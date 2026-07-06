# Mailtrap Setup - Simple Email Testing

Since Gmail App Passwords aren't available for your account, use **Mailtrap** instead. It's free and perfect for testing!

## What is Mailtrap?

Mailtrap catches all emails sent by your app so you can test the forgot password feature without sending real emails. You can see exactly what your users will receive.

## Setup Steps (5 minutes)

### 1. Create Free Mailtrap Account

1. Go to: **https://mailtrap.io**
2. Click **Sign Up** (it's FREE)
3. Sign up with your email or Google account
4. Verify your email

### 2. Get Your SMTP Credentials

1. After login, you'll see an **Inbox**
2. Click on the inbox (usually called "My Inbox" or "Demo Inbox")
3. Look for **SMTP Settings** section
4. Select **Laravel** from the integration dropdown
5. You'll see something like:

```env
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=1a2b3c4d5e6f7g  # Your username
MAIL_PASSWORD=1a2b3c4d5e6f7g  # Your password
MAIL_ENCRYPTION=tls
```

### 3. Update Your .env File

Open `kaya_backend/.env` and replace:

```env
MAIL_USERNAME=get_from_mailtrap
MAIL_PASSWORD=get_from_mailtrap
```

With your actual Mailtrap credentials from step 2.

**Example:**
```env
MAIL_USERNAME=a1b2c3d4e5f6g7
MAIL_PASSWORD=a1b2c3d4e5f6g7
```

### 4. Clear Laravel Config Cache

```bash
cd kaya_backend
php artisan config:clear
```

### 5. Test It!

```bash
cd kaya_backend
php artisan tinker
```

Then run:
```php
use App\Mail\PasswordResetMail;
use Illuminate\Support\Facades\Mail;

Mail::to('test@example.com')->send(new PasswordResetMail('Test User', '123456'));
```

### 6. Check Mailtrap Inbox

1. Go back to **https://mailtrap.io**
2. Click on your inbox
3. You should see the email there! 📧
4. You can preview it, check the HTML, and see exactly what it looks like

## Testing Forgot Password Flow

Now test your app:

1. Open your Flutter app
2. Go to Login → **Forgot Password?**
3. Enter any email address
4. Check your **Mailtrap inbox** to see the 6-digit code
5. Enter the code in the app
6. Set a new password
7. Done! ✅

## Advantages of Mailtrap

✅ **No real emails sent** - Perfect for testing
✅ **Free forever** - No credit card needed
✅ **See all email details** - HTML, text, headers
✅ **No Gmail restrictions** - Works immediately
✅ **Team access** - Share inbox with developers
✅ **Test spam score** - Check if your emails look spammy

## For Production (Later)

When you're ready to send real emails, you can use:
- **SendGrid** (free tier: 100 emails/day)
- **Mailgun** (free tier: 5000 emails/month)
- **Amazon SES** (very cheap, $0.10 per 1000 emails)

But for now, **Mailtrap is perfect for development and testing!**

## Quick Visual Guide

1. **Mailtrap Dashboard:**
   ```
   My Inbox (0 messages)
   └── SMTP Settings
       └── Integrations: [Laravel] ← Select this
           └── MAIL_HOST: sandbox.smtp.mailtrap.io
           └── MAIL_PORT: 2525
           └── MAIL_USERNAME: xxxxxxxxx ← Copy this
           └── MAIL_PASSWORD: xxxxxxxxx ← Copy this
   ```

2. **Your .env:**
   ```env
   MAIL_MAILER=smtp
   MAIL_HOST=sandbox.smtp.mailtrap.io
   MAIL_PORT=2525
   MAIL_USERNAME=xxxxxxxxx  # Paste from Mailtrap
   MAIL_PASSWORD=xxxxxxxxx  # Paste from Mailtrap
   MAIL_ENCRYPTION=tls
   ```

3. **Test:**
   ```bash
   php artisan config:clear
   php artisan tinker
   >>> Mail::to('test@test.com')->send(new \App\Mail\PasswordResetMail('Test', '123456'));
   ```

4. **Check Mailtrap** → See your email! 🎉

## Troubleshooting

### "Connection refused"
- Double-check username and password from Mailtrap
- Make sure you ran `php artisan config:clear`

### Email not showing in Mailtrap
- Refresh the inbox page
- Check you're looking at the right inbox
- Look for errors in `storage/logs/laravel.log`

### "Authentication failed"
- Copy username and password exactly from Mailtrap (no extra spaces)
- Make sure MAIL_ENCRYPTION=tls (not ssl)

## Current Setup

```env
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=get_from_mailtrap  # ← UPDATE THIS
MAIL_PASSWORD=get_from_mailtrap  # ← UPDATE THIS
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@kaya.com"
MAIL_FROM_NAME="KAYA"
```

---

**Next Steps:**
1. Sign up at mailtrap.io (2 min)
2. Copy your credentials (1 min)
3. Update .env (1 min)
4. Run `php artisan config:clear` (10 sec)
5. Test and see emails in Mailtrap! ✅

Much easier than dealing with Gmail restrictions! 🚀
