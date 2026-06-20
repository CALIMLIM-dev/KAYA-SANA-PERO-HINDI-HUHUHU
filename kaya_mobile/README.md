# KAYA Mobile App 📱

Flutter-based mobile application for the KAYA home service platform.

## ✨ Features

### Implemented ✅
- **Splash Screen** - Beautiful app intro
- **Authentication**
  - Login Screen
  - Signup Screen
  - Social Login Buttons
  - Custom Text Fields
- **Home Screen**
  - Featured Job Cards
  - Worker Cards
  - Category Cards
  - Search Functionality
- **Navigation**
  - Bottom Navigation Bar
  - Main Navigation with 4 tabs
- **Bookings Screen** - View and manage bookings
- **Messages Screen** - Chat functionality
- **Profile Screen** - User profile management

## 🎨 UI/UX
- Custom color scheme (Primary: #4A5FFF)
- Material Design 3
- Custom fonts (Poppins)
- Smooth animations
- Responsive layouts

## 🏗️ Architecture
- **Clean Architecture**
- **BLoC Pattern** for state management
- **Feature-based** folder structure
- **Separation of concerns** (presentation, domain, data)

## 📁 Project Structure
```
lib/
├── core/
│   ├── routes/         # App navigation
│   └── theme/          # App theming
├── features/
│   ├── auth/           # Authentication
│   ├── home/           # Home screen
│   ├── bookings/       # Bookings management
│   ├── messages/       # Messaging
│   ├── profile/        # User profile
│   └── splash/         # Splash screen
└── main.dart           # App entry point
```

## 🚀 How to Run

### Web (Easiest)
```bash
flutter run -d edge
```

### Android (MuMu Player)
```bash
flutter run -d 127.0.0.1:16384
```

### From Project Root
```powershell
.\run_web.ps1          # Run on web
.\run_mumu.ps1         # Run on Android
```

## 📦 Dependencies
- flutter_bloc - State management
- go_router - Navigation
- google_fonts - Custom fonts
- http - API calls
- flutter_secure_storage - Secure data storage

## 🔌 API Integration

### Backend Connection
The app is designed to connect to the Laravel backend at:
- Local: `http://localhost:8000`
- Production: Update in API config

### Endpoints (To implement)
- POST `/api/auth/login`
- POST `/api/auth/register`
- GET `/api/jobs`
- GET `/api/workers`
- POST `/api/bookings`

## 🎯 Next Steps
1. Integrate with Laravel backend API
2. Add real data from backend
3. Implement booking flow
4. Add payment integration
5. Implement messaging system
6. Add push notifications

## 🐛 Debug
```bash
flutter clean
flutter pub get
flutter run
```

## 📱 Build for Production
```bash
# Android APK
flutter build apk --release

# iOS (requires Mac)
flutter build ios --release
```

---

**Status:** ✅ Frontend Complete - Ready for API Integration
