# Google Sign-In - The REAL Fix

## The Problem:
Google Sign-In on Android requires:
1. **SHA-1 certificate** added to Google Cloud Console ✅ (you already did this)
2. **OAuth 2.0 Client ID** for Android created in Google Cloud Console

## The Solution:

### 1. Go to Google Cloud Console
https://console.cloud.google.com/apis/credentials?project=stellar-day-500708-d5

### 2. Check if you have an Android OAuth Client ID:
- Look for: "Client ID for Android"
- Type: "Android"
- Package name: `com.example.kaya_app`

### 3. If you DON'T have it, create one:
- Click **"+ CREATE CREDENTIALS"** → **OAuth client ID**
- Application type: **Android**
- Name: **KAYA Android**
- Package name: **com.example.kaya_app**
- SHA-1 certificate fingerprint: **[Your debug SHA-1]**
- Click **Create**

### 4. That's it!

The OAuth Client ID you have (`217067120890...`) is for **Web/Desktop**, not Android.

Android uses SHA-1 fingerprint matching instead of explicit client IDs in the code.

Once you create the Android OAuth Client ID with your SHA-1, the Google account picker will show.

## Quick Check:
In Google Cloud Console → Credentials, you should see **TWO** OAuth Client IDs:
1. ✅ Web client (installed) - `217067120890-b5p9b0lkath30n40ph3ii14gamnk1oom...`
2. ❌ Android client - **MISSING** (need to create this)

Create the Android one with your SHA-1 and it will work!
