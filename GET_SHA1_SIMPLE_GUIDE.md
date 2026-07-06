# Get SHA-1 Certificate - Simple Step-by-Step Guide

## ✅ Easiest Method: Using Android Studio

Since your debug keystore exists but Java/keytool is not in PATH, use Android Studio:

### Step-by-Step Instructions:

#### 1. Open Android Studio
   - Launch Android Studio on your computer

#### 2. Open Your Flutter Project
   - Click **File** → **Open**
   - Navigate to: `C:\Users\CALIMLIM\Downloads\KAYA SANA PERO HINDI HUHUHU\kaya_app`
   - Click **OK**

#### 3. Wait for Gradle Sync
   - Let Android Studio finish indexing and syncing (bottom status bar)
   - This may take a few minutes the first time

#### 4. Open Gradle Panel
   - On the **right side** of Android Studio, click the **Gradle** tab (looks like an elephant icon)
   - If you don't see it, go to: **View** → **Tool Windows** → **Gradle**

#### 5. Navigate to Signing Report
   - In the Gradle panel, expand these folders in order:
     ```
     kaya_app
       └── android
           └── Tasks
               └── android
                   └── signingReport  ← Double-click this
     ```

#### 6. View the Results
   - A **Run** panel will open at the bottom
   - Scroll through the output to find:
   
   ```
   Variant: debug
   Config: debug
   Store: C:\Users\CALIMLIM\.android\debug.keystore
   Alias: AndroidDebugKey
   MD5: 12:34:56:78:90:AB:CD:EF:...
   SHA1: A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0  ← THIS IS YOUR SHA-1
   SHA-256: ...
   Valid until: ...
   ```

#### 7. Copy Your SHA-1
   - **Select and copy** the entire SHA-1 line (looks like `XX:XX:XX:...`)
   - Example: `A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0`

---

## 🎯 What to Do Next

### Add SHA-1 to Firebase Console:

1. Go to: https://console.firebase.google.com/
2. Select your project
3. Click the **⚙️ Settings** icon → **Project settings**
4. Scroll down to **Your apps** section
5. Click on your **Android app** (package: `com.kaya.app` or similar)
6. Scroll to **SHA certificate fingerprints**
7. Click **Add fingerprint** button
8. Paste your SHA-1
9. Click **Save**
10. Download the updated `google-services.json` file

### Add SHA-1 to Google Cloud Console:

1. Go to: https://console.cloud.google.com/
2. Select your project
3. Go to: **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 Client ID** (Type: Android)
5. Click the **pencil icon** (edit)
6. Under **SHA-1 certificate fingerprint**, click **Add fingerprint**
7. Paste your SHA-1
8. Click **Save**

### Update google-services.json:

1. Download the updated `google-services.json` from Firebase (step 10 above)
2. Replace the file in your Flutter project:
   ```
   kaya_app/android/app/google-services.json
   ```
3. Rebuild your app:
   ```bash
   cd kaya_app
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 📋 Quick Checklist

- [ ] Opened Android Studio
- [ ] Opened kaya_app project
- [ ] Ran Gradle signingReport
- [ ] Copied Debug SHA-1
- [ ] Added SHA-1 to Firebase Console
- [ ] Added SHA-1 to Google Cloud Console
- [ ] Downloaded updated google-services.json
- [ ] Placed google-services.json in android/app/
- [ ] Ran flutter clean && flutter pub get
- [ ] Tested Google Sign-In

---

## 🚨 Common Issues

### "Gradle sync failed"
**Solution:** 
```bash
cd kaya_app/android
./gradlew clean
```

### "signingReport task not showing"
**Solution:** 
- Click the **refresh** icon in the Gradle panel (circular arrows)
- Or restart Android Studio

### Google Sign-In still not working after adding SHA-1
**Wait 5-10 minutes** for Google services to update, then:
1. Uninstall the app from your device/emulator
2. Run: `flutter clean`
3. Rebuild and reinstall: `flutter run`

### Can't find Gradle panel
**Solution:**
- Click: **View** → **Tool Windows** → **Gradle**
- Or press: **Ctrl + Alt + S** → Search for "Gradle"

---

## 💡 Pro Tips

1. **Save your SHA-1**: Copy it to a text file for future reference
2. **Release SHA-1**: When you create a release build, you'll need to get the release SHA-1 too
3. **Multiple developers**: Each developer's debug.keystore has a different SHA-1 - add all of them
4. **Testing on different machines**: Each machine needs its debug SHA-1 added

---

## 📝 Example Output You're Looking For

When you run `signingReport`, look for this:

```
> Task :app:signingReport
Variant: debug
Config: debug
Store: C:\Users\CALIMLIM\.android\debug.keystore
Alias: AndroidDebugKey
MD5: 1A:2B:3C:4D:5E:6F:7G:8H:9I:0J:1K:2L:3M:4N:5O:6P
SHA1: A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0  ← COPY THIS!
SHA-256: 1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T1U2V3W4X5Y6Z7A8B9C0D1E2F
Valid until: Monday, January 1, 2050
```

**Copy the SHA1 line** (the one with colons separating pairs of characters)

---

## ✅ Done!

Once you have your SHA-1:
1. Add it to Firebase
2. Add it to Google Cloud Console  
3. Download new google-services.json
4. Rebuild your app
5. Test Google Sign-In

Your debug keystore location:
```
C:\Users\CALIMLIM\.android\debug.keystore
```

Good luck! 🚀
