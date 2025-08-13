#!/bin/bash

# Flutter App Build Script for MapTag BF
# This script builds the Flutter app for Android

set -e

echo "================================================"
echo "MapTag BF Flutter App Build Script"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Navigate to Flutter project directory
cd /workspaces/MapTag/frontend/maptag_bf

# Set Flutter path
export PATH="$PATH:/workspaces/MapTag/frontend/maptag_bf/flutter/bin"

echo -e "${YELLOW}Checking Flutter environment...${NC}"
flutter doctor

echo -e "${YELLOW}Getting dependencies...${NC}"
flutter pub get

echo -e "${YELLOW}Running Flutter analyze...${NC}"
flutter analyze || true

echo -e "${YELLOW}Running tests...${NC}"
flutter test || true

# Build options
BUILD_TYPE=${1:-apk}  # Default to APK
BUILD_MODE=${2:-release}  # Default to release mode

echo -e "${YELLOW}Building Flutter app (${BUILD_TYPE} in ${BUILD_MODE} mode)...${NC}"

case $BUILD_TYPE in
  apk)
    if [ "$BUILD_MODE" = "release" ]; then
      flutter build apk --release
      echo -e "${GREEN}✓ Release APK built successfully!${NC}"
      echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
    else
      flutter build apk --debug
      echo -e "${GREEN}✓ Debug APK built successfully!${NC}"
      echo "APK location: build/app/outputs/flutter-apk/app-debug.apk"
    fi
    ;;
  
  bundle)
    flutter build appbundle --release
    echo -e "${GREEN}✓ App Bundle built successfully!${NC}"
    echo "Bundle location: build/app/outputs/bundle/release/app-release.aab"
    ;;
  
  web)
    flutter build web --release
    echo -e "${GREEN}✓ Web build completed successfully!${NC}"
    echo "Web build location: build/web"
    ;;
  
  *)
    echo -e "${RED}Unknown build type: $BUILD_TYPE${NC}"
    echo "Usage: $0 [apk|bundle|web] [debug|release]"
    exit 1
    ;;
esac

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"

# Show build artifacts
echo -e "${YELLOW}Build artifacts:${NC}"
find build -name "*.apk" -o -name "*.aab" 2>/dev/null || true