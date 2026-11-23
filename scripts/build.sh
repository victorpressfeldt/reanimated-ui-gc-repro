#!/usr/bin/env bash
# Builds a release APK (arm64, signed with the debug keystore) into ./ui-gc-repro.apk.
# Needs ANDROID_HOME, JDK 17 and `npm install` done.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ANDROID_HOME:?set ANDROID_HOME to your Android SDK}"

for p in expo react-native react-native-reanimated react-native-worklets; do
  echo "$p $(node -p "require('./node_modules/$p/package.json').version")"
done

CI=1 npx expo prebuild --platform android --clean --no-install
cd android
./gradlew assembleRelease -PreactNativeArchitectures=arm64-v8a
cp app/build/outputs/apk/release/app-release.apk ../ui-gc-repro.apk
ls -l ../ui-gc-repro.apk
