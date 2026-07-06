# Testing Profile Features

## 1. Profile Picture Upload

### Steps:
1. Open app and login
2. Go to "My Worker Profile" from home screen
3. Tap on the profile photo circle (top left in header)
4. Choose "Gallery" or "Camera"
5. Select/take a photo
6. Photo should upload and display immediately

### What happens:
- Provider calls `uploadPhoto(fromCamera: bool)`
- Sends multipart request to `POST /api/v1/worker/profile/photo`
- Backend saves to `storage/profile_photos/`
- Updates user's `avatar` column
- Photo displays via `ApiClient.fileUrl(path)`

### If not working check:
- Image picker permission in AndroidManifest.xml
- Backend storage folder is writable: `php artisan storage:link`
- Network connectivity to ngrok URL
- Check Laravel logs: `tail -f storage/logs/laravel.log`

## 2. Verifications Tab

### Steps:
1. Go to "My Worker Profile"
2. Tap "Verifications" tab (second tab)
3. Should show 3 verification types:
   - Government ID
   - Phone Number  
   - Email

### What happens:
- Provider calls `fetchVerifications()`
- Sends `GET /api/v1/verifications`
- Shows status: unverified / pending / verified

### If showing empty:
- Verifications table was wiped with database
- Need to submit new verifications
- Tap any verification card → upload document → check status

## 3. Name / Location / Phone Update

### Steps:
1. In Profile tab, tap "Full Name" card
2. Enter name → Save
3. Should update immediately
4. Same for Location and Personal Details

### Backend endpoints:
- `PUT /api/v1/worker/profile` with `{name: "..."}` or `{city: "..."}` or `{phone: "..."}`

## 4. Licenses & Certifications

### Steps:
1. Tap "Licenses" card
2. Tap "Add License" button
3. Fill form:
   - License Name
   - License Number
   - Issued By
   - Date Issued (date picker)
   - Upload photo/PDF
   - Check confirmation box
4. Tap Save
5. Should appear in list

### Backend:
- `POST /api/v1/worker/licenses`
- Data saved to `worker_licenses` table
- File upload NOT YET IMPLEMENTED (will add later)

## Debugging Commands

```bash
# Check Laravel logs
cd kaya_backend
tail -f storage/logs/laravel.log

# Check uploaded files
ls -la storage/app/public/profile_photos/

# Create storage link if missing
php artisan storage:link

# Check database
php artisan tinker
>>> User::first()
>>> WorkerLicense::all()
>>> WorkerCertification::all()
```

## Known Issues

1. **Document upload for certs/licenses** - File picker opens but file isn't saved to server yet
2. **Experience section** - No backend API yet
3. **Skills route** - Points to wrong screen (license examinations)
