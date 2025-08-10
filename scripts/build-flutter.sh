#!/bin/bash

# MapTag BF Flutter App Build Script
echo "🔨 Building MapTag BF Flutter App"
echo "================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    echo ""
    echo "For Ubuntu/Linux:"
    echo "   wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz"
    echo "   tar xf flutter_linux_3.16.0-stable.tar.xz"
    echo "   export PATH=\"\$PATH:`pwd`/flutter/bin\""
    exit 1
fi

# Navigate to Flutter app directory
cd frontend/maptag_bf || {
    echo "❌ Flutter app directory not found"
    exit 1
}

echo "📦 Installing Flutter dependencies..."
flutter pub get

echo "🔍 Running Flutter doctor..."
flutter doctor

echo "🧪 Running tests..."
flutter test

echo "🔨 Building debug APK..."
flutter build apk --debug

echo "🏗️ Building release APK..."
flutter build apk --release

echo "✅ Build completed!"
echo ""
echo "📱 APK Locations:"
echo "   Debug:   build/app/outputs/flutter-apk/app-debug.apk"
echo "   Release: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📋 Next steps:"
echo "   1. Test APK on Android device"
echo "   2. Update API base URL for production"
echo "   3. Test offline functionality"
echo "   4. Distribute to users"