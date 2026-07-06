# How to Get SHA-1 Certificate for Android

SHA-1 certificates are needed for:
- Google Sign-In
- Firebase Authentication
- Google Maps API
- Other Google services

## Method 1: Using Android Studio (Easiest)

### For Debug SHA-1:

1. **Open Android Studio**
2. **Open your Flutter project** (kaya_app)
3. **Click on Gradle tab** (right side of Android Studio)
4. **Navigate to:**
   ```
   kaya_app > android > Tasks > android > signingReport
   ```
5. **Double-click on `signingReport`**
6. **Look for output** in the Run panel at the bottom
7. **Copy the SHA-1** from the debug variant

Example output:
```
Variant: debug
Config: debug
Store: C:\Users\CALIMLIM\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX  ← COPY THIS
SHA-256: XX:XX:XX:...
```

### For Release SHA-1:

If you have a release keystore (upload-keystore.jks):
1. Same steps as above
2. Look for the `release` variant instead of debug

---

## Method 2: Using Command Line (Requires Java)

### Install Java First (if not installed):

**Download Java JDK:**
- Go to: https://www.oracle.com/java/technologies/downloads/
- Download Java 17 or 21 (LTS versions)
- Install it
- Add to PATH: `C:\Program Files\Java\jdk-XX\bin`

### Get Debug SHA-1:

```cmd
cd %USERPROFILE%\.android
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Default password:** `android`

### Get Release SHA-1 (if you have upload keystore):

```cmd
cd C:\Users\CALIMLIM\Downloads\KAYA SANA PERO HINDI HUHUHU\kaya_app\android\app
keytool -list -v -keystore upload-keystore.jks -alias upload
```

Enter the keystore password when prompted.

---

## Method 3: Using Flutter Command

```bash
cd kaya_app
flutter build apk --debug
```

Then check the build output for signing information.

---

## Method 4: Using Gradle Signing Report

**Prerequisites:** Java must be installed

```bash
cd kaya_app/android
gradlew signingReport
```

Or on Windows:
```cmd
cd kaya_app\android
gradlew.bat signingReport
```

---

## Method 5: Quick PowerShell Script

Save this as `get-sha1.ps1`:

```powershell
# Get Debug SHA-1
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    Write-Host "Debug Keystore found!" -ForegroundColor Green
    Write-Host "Run this command:" -ForegroundColor Yellow
    Write-Host "keytool -list -v -keystore `"$debugKeystore`" -alias androiddebugkey -storepass android -keypass android"
} else {
    Write-Host "Debug keystore not found at: $debugKeystore" -ForegroundColor Red
    Write-Host "Run your Flutter app once to generate it: flutter run" -ForegroundColor Yellow
}

# Check if keytool is available
try {
    $javaHome = $env:JAVA_HOME
    if ($javaHome) {
        $keytool = "$javaHome\bin\keytool.exe"
        if (Test-Path $keytool) {
            Write-Host "`nRunning keytool..." -ForegroundColor Green
            & $keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android
        }
    }
} catch {
    Write-Host "`nJava not found. Please install Java JDK." -ForegroundColor Red
}
```

---

## What to Do With SHA-1 Certificate

### For Google Sign-In (Google Cloud Console):

1. Go to: https://console.cloud.google.com/
2. Select your project
3. Navigate to: **APIs & Services > Credentials**
4. Find your **OAuth 2.0 Client ID** (Android type)
5. Edit it
6. Add your **SHA-1 certificate fingerprint**
7. Save

### For Firebase:

1. Go to: https://console.firebase.google.com/
2. Select your project
3. Go to: **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Click on your Android app
6. Scroll to **SHA certificate fingerprints**
7. Click **Add fingerprint**
8. Paste your SHA-1
9. Save

### You Need BOTH:

- **Debug SHA-1** - For development/testing on your computer
- **Release SHA-1** - For published app on Play Store

---

## Common Issues

### "keytool not found"
**Solution:** Install Java JDK and add to PATH

### "debug.keystore not found"
**Solution:** Run `flutter run` once to generate it automatically

### "Wrong password"
**Solution:** Debug keystore password is always `android`

### Google Sign-In still not working
**Solutions:**
1. Make sure you added SHA-1 to BOTH Google Cloud Console AND Firebase
2. Wait 5-10 minutes for changes to propagate
3. Download updated `google-services.json` from Firebase
4. Place it in: `kaya_app/android/app/google-services.json`
5. Rebuild your app: `flutter clean && flutter pub get && flutter run`

---

## Quick Check Your Current Setup

Run this in PowerShell:

```powershell
# Check if debug keystore exists
Test-Path "$env:USERPROFILE\.android\debug.keystore"

# Check if Java is installed
java -version

# Check if keytool is available
keytool -help
```

If any return errors, you need to install Java first.

---

## Recommended: Save Your SHA-1 Certificates

Create a file `SHA1_CERTIFICATES.txt` in your project:

```
=== KAYA App SHA-1 Certificates ===

Debug SHA-1 (Development):
[PASTE YOUR DEBUG SHA-1 HERE]

Release SHA-1 (Production):
[PASTE YOUR RELEASE SHA-1 HERE]

Generated on: [DATE]

Notes:
- Debug: Used for local development
- Release: Used for Play Store builds
- Both are registered in Google Cloud Console
- Both are registered in Firebase Console
```

This helps you keep track of which certificates are registered where.

---

## Need Help?

If you're still having issues, provide:
1. Your operating system
2. Whether Java is installed
3. The exact error message you're seeing
4. What you're trying to achieve (Google Sign-In, Firebase, etc.)
