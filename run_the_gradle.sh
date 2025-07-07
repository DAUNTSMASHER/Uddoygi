#!/bin/bash

echo "🚀 Flutter Clean & Gradle Warm-Up Script Started"

cd "$(dirname "$0")"

echo "🧹 Cleaning Flutter project..."
flutter clean

echo "🧹 Removing Gradle and Flutter caches..."
rm -rf ~/.gradle/caches/
rm -rf ~/.gradle/daemon/
rm -rf ~/.gradle/native/
rm -rf android/.gradle/

echo "📦 Running flutter pub get..."
flutter pub get

echo "🔥 Pre-downloading Gradle & Kotlin dependencies..."
cd android
./gradlew dependencies --refresh-dependencies
cd ..

echo "🛠️ Building debug APK..."
flutter build apk --debug

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$APK_PATH" ]; then
    echo "✅ APK built successfully at $APK_PATH"

    EMULATOR=$(adb devices | awk 'NR==2 {print $1}')
    if [ "$EMULATOR" != "" ] && [ "$EMULATOR" != "List" ]; then
        echo "📲 Installing APK to device: $EMULATOR"
        adb install -r "$APK_PATH"
    else
        echo "⚠️ No device found. Please start an emulator."
    fi
else
    echo "❌ APK not found! Build may have failed."
fi

echo "✅ Done."

