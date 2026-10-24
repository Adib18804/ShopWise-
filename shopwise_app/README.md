# ShopWise Mobile App

Smart Business Assistant for Small Grocery Shopkeepers in Bangladesh - Android Application

## Overview

ShopWise is a Flutter-based Android mobile application that helps small grocery shopkeepers make better business decisions through intelligent analysis and recommendations.

## Features

- 📊 **Smart Dashboard** - Real-time business insights and recommendations
- 📦 **Product Management** - Easy product and inventory tracking
- 🔄 **Multi-Batch Tracking** - FEFO (First Expire First Out) support
- 💰 **Sales Recording** - Quick and simple sales entry
- ⚠️ **Expiry Intelligence** - Alerts for products nearing expiry
- 📉 **Stock-Out Prediction** - Proactive low-stock warnings
- 🔄 **Restock Recommendations** - Data-driven purchasing guidance
- 🐌 **Slow-Moving Detection** - Identify products with low sales
- 📈 **Profit Analysis** - Understand your business performance
- 🔔 **Push Notifications** - Timely alerts and reminders
- 🌐 **Bangla Support** - Full localization for Bengali language

## Tech Stack

- **Framework:** Flutter 3.x
- **Language:** Dart
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **API Client:** Dio + Retrofit
- **Local Storage:** flutter_secure_storage, SharedPreferences
- **Push Notifications:** Firebase Cloud Messaging
- **Localization:** flutter_localizations

## Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android SDK (API level 21+)
- Firebase project configured

## Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd shopwise_app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Generate code** (for Riverpod, Retrofit, Freezed)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. **Configure Firebase**
   - Download `google-services.json` from Firebase Console
   - Place it in `android/app/` directory

5. **Configure API endpoint**
   - Update API base URL in `lib/core/constants/api_constants.dart`

## Running the App

### Development Mode
```bash
flutter run
```

### Release Mode
```bash
flutter run --release
```

### Build APK
```bash
flutter build apk --release
```

### Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App-wide constants
│   ├── theme/              # Material 3 theme
│   ├── localization/       # i18n strings
│   ├── network/            # API client setup
│   ├── storage/            # Local storage
│   └── utils/              # Utility functions
│
├── models/                 # Data models
│
├── services/               # API services
│
├── providers/              # Riverpod providers
│
├── features/               # Feature modules
│   ├── auth/              # Authentication
│   ├── onboarding/        # Shop setup
│   ├── dashboard/         # Home dashboard
│   ├── products/          # Product management
│   ├── stock/             # Stock & batches
│   ├── sales/             # Sales recording
│   ├── insights/          # Analytics & insights
│   ├── notifications/     # Notifications
│   └── profile/           # User profile & settings
│
├── widgets/               # Reusable widgets
│
├── routes/                # Navigation configuration
│
└── main.dart              # App entry point
```

## Key Files

- `pubspec.yaml` - Dependencies and configuration
- `lib/main.dart` - Application entry point
- `lib/core/constants/api_constants.dart` - API endpoints
- `lib/core/theme/app_theme.dart` - Material 3 theme
- `lib/routes/app_router.dart` - Navigation routes
- `android/app/build.gradle` - Android build configuration
- `android/app/google-services.json` - Firebase configuration

## Configuration

### API Endpoint

Update the base URL in `lib/core/constants/api_constants.dart`:

```dart
static const String baseUrl = 'https://your-api-domain.com/api/v1';
```

### Firebase

1. Create a Firebase project
2. Add Android app to Firebase project
3. Download `google-services.json`
4. Place in `android/app/`
5. Enable Cloud Messaging in Firebase Console

### Languages

Supported languages:
- English (en)
- Bangla (bn)

Add new translations in `lib/core/localization/`

## Testing

### Run all tests
```bash
flutter test
```

### Run with coverage
```bash
flutter test --coverage
```

### Widget tests
```bash
flutter test test/widgets/
```

## Code Generation

When you modify files with code generation annotations:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Or use watch mode for automatic generation:

```bash
flutter pub run build_runner watch
```

## Linting

Check for linting issues:

```bash
flutter analyze
```

Format code:

```bash
flutter format lib/
```

## Build Configuration

### Development
- Debug mode
- Local API endpoint
- Debug logging enabled

### Production
- Release mode
- Production API endpoint
- Minimal logging
- Code obfuscation
- ProGuard/R8 enabled

## Android Build Settings

Key settings in `android/app/build.gradle`:

- **Minimum SDK:** 21 (Android 5.0)
- **Target SDK:** 34 (Android 14)
- **Compile SDK:** 34
- **Package Name:** com.shopwise.app

## Troubleshooting

### Firebase initialization fails
- Verify `google-services.json` is in `android/app/`
- Check package name matches Firebase configuration
- Rebuild the app: `flutter clean && flutter pub get`

### API connection issues
- Check API base URL configuration
- Verify backend server is running
- Check network permissions in AndroidManifest.xml

### Build errors after dependency update
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Hot reload not working
- Restart the app: `r` in terminal
- Full restart: `R` in terminal
- If issues persist, stop and restart `flutter run`

## Release Checklist

Before releasing to Play Store:

- [ ] Update version in `pubspec.yaml`
- [ ] Configure production API endpoint
- [ ] Test on multiple device sizes
- [ ] Test in release mode
- [ ] Generate signed AAB
- [ ] Test installation from AAB
- [ ] Prepare Play Store assets (screenshots, description)
- [ ] Review privacy policy
- [ ] Test push notifications
- [ ] Verify all features work offline gracefully

## Performance Tips

- Use `const` constructors where possible
- Implement pagination for large lists
- Cache network images
- Minimize widget rebuilds with Riverpod
- Use `ListView.builder` for long lists
- Profile with Flutter DevTools

## Security

- Tokens stored in flutter_secure_storage
- API credentials in environment variables
- No hardcoded secrets in code
- HTTPS for all API calls
- Input validation on all forms

## Localization

Add new strings:

1. Add key-value in `lib/core/localization/l10n_en.dart`
2. Add translation in `lib/core/localization/l10n_bn.dart`
3. Use in code: `context.l10n.yourKey`

## Support

For documentation, see:
- `/ARCHITECTURE.md` - System architecture
- `/API.md` - Backend API documentation
- `/DATABASE.md` - Database schema
- `/BUSINESS_LOGIC.md` - Business rules

## License

MIT License
