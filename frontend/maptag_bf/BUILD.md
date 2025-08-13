# MapTag BF Flutter App Build Instructions

## Project Setup Completed ✓

The Flutter mobile app for MapTag BF has been successfully set up with:

### ✅ Completed Tasks
1. **Flutter SDK installed** (v3.24.0)
2. **Project structure created** with Android/iOS/Web platform directories
3. **Dependencies installed** including:
   - GPS/Location services (geolocator)
   - Camera & image handling
   - QR code generation/scanning
   - Local SQLite database
   - Offline support
   - HTTP API connectivity
4. **Android configuration** completed:
   - Min SDK: 21 (Android 5.0+)
   - Target SDK: 34 (Android 14)
   - Required permissions added
5. **Tests verified** - All tests passing

## Directory Structure
```
maptag_bf/
├── android/          # Android platform files ✓
├── ios/             # iOS platform files ✓
├── web/             # Web platform files ✓
├── lib/             # Dart source code
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   └── services/
├── assets/          # Images and resources
├── test/            # Test files
└── pubspec.yaml     # Dependencies
```

## Build Requirements

### For Android APK Build
- Android SDK (API 34)
- Java JDK 11-19
- Android build tools

### For iOS Build (macOS only)
- Xcode 14+
- iOS SDK
- Valid Apple Developer account (for device deployment)

## Build Commands

### Install Dependencies
```bash
flutter pub get
```

### Run Tests
```bash
flutter test
```

### Build Android APK
```bash
# Debug build (for testing)
flutter build apk --debug

# Release build (for production)
flutter build apk --release
```

### Build iOS (macOS only)
```bash
flutter build ios --release
```

### Build for Web
```bash
flutter build web --release
```

## Using the Build Script
A convenient build script is available:
```bash
# Build release APK
./scripts/build-flutter-app.sh apk release

# Build debug APK
./scripts/build-flutter-app.sh apk debug

# Build app bundle for Play Store
./scripts/build-flutter-app.sh bundle release

# Build for web
./scripts/build-flutter-app.sh web release
```

## Output Locations
- **APK (Debug)**: `build/app/outputs/flutter-apk/app-debug.apk`
- **APK (Release)**: `build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`
- **Web Build**: `build/web/`

## Next Steps for Full Build

To complete the Android build, you need to:

1. **Install Android SDK** on your build machine:
   ```bash
   # Option 1: Install Android Studio
   # Download from https://developer.android.com/studio
   
   # Option 2: Command line tools only
   wget https://dl.google.com/android/repository/commandlinetools-linux-latest.zip
   unzip commandlinetools-linux-latest.zip
   ./cmdline-tools/bin/sdkmanager --sdk_root=$HOME/Android/Sdk "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   ```

2. **Set environment variables**:
   ```bash
   export ANDROID_HOME=$HOME/Android/Sdk
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   ```

3. **Accept licenses**:
   ```bash
   flutter doctor --android-licenses
   ```

4. **Build the APK**:
   ```bash
   flutter build apk --release
   ```

## Development Setup
For development and testing:
```bash
# Run on connected device/emulator
flutter run

# Run with hot reload
flutter run --debug

# Run on web browser
flutter run -d chrome
```

## Current Status
- ✅ Flutter project initialized
- ✅ All dependencies configured
- ✅ Android manifest configured
- ✅ Build settings optimized
- ✅ Tests passing
- ⚠️ Android SDK required for APK generation

The app is ready for building once Android SDK is installed!