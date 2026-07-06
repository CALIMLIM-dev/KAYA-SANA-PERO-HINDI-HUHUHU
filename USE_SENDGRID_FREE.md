# Use SendGrid (Free & Production-Ready)

For deployment, use **SendGrid** - it's free, no password needed, works with just an API key.

## Setup (2 minutes):

1. **Sign up**: https://sendgrid.com (FREE - 100 emails/day forever)
2. **Get API Key**: Settings → API Keys → Create API Key
3. **Update .env**:

```env
MAIL_MAILER=sendgrid
SENDGRID_API_KEY=your_sendgrid_api_key_here
MAIL_FROM_ADDRESS="noreply@kaya.com"
MAIL_FROM_NAME="KAYA"
```

4. **Install**: `composer require s-ichikawa/laravel-sendgrid-driver`
5. **Done**. No passwords, no OAuth, just works.

SendGrid is what production apps use. Way better than Gmail for deployment.
