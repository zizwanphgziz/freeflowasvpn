#!/usr/bin/env bash
# Freeflow native APK builder
# Requirements:
#   - Java 17 (JAVA_HOME pointed at JDK 17)
#   - Android SDK with platforms;android-35 + build-tools;35.0.0 + ndk;27.1.12297006
#   - Node 20+ / npm
#
# Usage:
#   cd mobile
#   ./scripts/build-apk.sh
#
# Output:
#   mobile/android/app/build/outputs/apk/release/app-release.apk

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ERROR: ANDROID_HOME / ANDROID_SDK_ROOT not set." >&2
  exit 1
fi

export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

if ! command -v java >/dev/null; then
  echo "ERROR: java not found in PATH" >&2
  exit 1
fi

java_version="$(java -version 2>&1 | head -n1)"
if ! echo "$java_version" | grep -q '"17'; then
  echo "WARN: expected Java 17, got: $java_version" >&2
fi

echo "==> Installing npm dependencies"
npm install --no-audit --no-fund --legacy-peer-deps

echo "==> Running expo prebuild (android)"
echo y | npx expo prebuild --platform android --clean --no-install

echo "==> Installing release keystore"
mkdir -p android/app
cp keystore/freeflow-release.keystore android/app/freeflow-release.keystore

echo "==> Patching android/app/build.gradle for release signing"
python3 - "$ROOT_DIR/android/app/build.gradle" <<'PY'
import re, sys
p = sys.argv[1]
src = open(p).read()
if 'freeflow-release.keystore' in src:
    sys.exit(0)
# Add release signing config + use it in release buildType
src = src.replace(
    """    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
    }""",
    """    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
        release {
            storeFile file(System.getenv('FREEFLOW_KEYSTORE_FILE') ?: 'freeflow-release.keystore')
            storePassword System.getenv('FREEFLOW_KEYSTORE_PASSWORD') ?: 'freeflow2025'
            keyAlias System.getenv('FREEFLOW_KEY_ALIAS') ?: 'freeflow'
            keyPassword System.getenv('FREEFLOW_KEY_PASSWORD') ?: 'freeflow2025'
        }
    }"""
)
src = src.replace(
    "        release {\n            // Caution! In production, you need to generate your own keystore file.\n            // see https://reactnative.dev/docs/signed-apk-android.\n            signingConfig signingConfigs.debug",
    "        release {\n            signingConfig signingConfigs.release"
)
# Add abiFilters for global compatibility
if 'abiFilters' not in src:
    src = src.replace(
        "        versionCode 1\n        versionName \"1.0.0\"",
        "        versionCode 1\n        versionName \"1.0.0\"\n        ndk {\n            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'\n        }"
    )
open(p, 'w').write(src)
PY

echo "==> Building release APK"
cd android
./gradlew assembleRelease --no-daemon

APK_PATH="$ROOT_DIR/android/app/build/outputs/apk/release/app-release.apk"
if [[ -f "$APK_PATH" ]]; then
  echo "==> Build succeeded:"
  ls -lh "$APK_PATH"
else
  echo "ERROR: APK not found at $APK_PATH" >&2
  exit 1
fi
