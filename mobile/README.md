# Freeflow Mobile App (Android)

Native Android app for **Freeflow** — built with React Native (Expo SDK 54).
Provides VPS/VPN management, terminal access, file manager and history on
Android devices.

## Output

`mobile/android/app/build/outputs/apk/release/app-release.apk` — a signed,
release-ready, universal APK (~176 MB) bundled with native libraries for all
four major ABIs (`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`). Works on any
Android 7.0+ device. The pre-built APK is also attached to the latest GitHub
release.

## Branding

- App name: **Freeflow**
- Package: `com.freeflow.app`
- Icon: derived from the FreeFlow wave logo
  (`assets/images/icon.png`, `assets/images/adaptive-icon.png`)

## Build requirements

| Tool | Version |
|------|---------|
| Java | 17 (JDK 17) |
| Node | 20+ |
| Android SDK | platforms 35, build-tools 35.0.0, NDK 27.1.12297006 |
| Android `minSdk` / `targetSdk` | 24 / 35 |

Install the Android SDK (Linux example):

```bash
mkdir -p ~/android-sdk/cmdline-tools
curl -sLo /tmp/cmdline.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q /tmp/cmdline.zip -d ~/android-sdk/cmdline-tools
mv ~/android-sdk/cmdline-tools/cmdline-tools ~/android-sdk/cmdline-tools/latest
export ANDROID_HOME=~/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
yes | sdkmanager --licenses >/dev/null
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;27.1.12297006"
```

## Build the signed release APK

From the repo root:

```bash
cd mobile
./scripts/build-apk.sh
```

The script:

1. Runs `npm install` (applies `patch-package` patches).
2. Runs `npx expo prebuild --platform android --clean` to generate the native
   Android project.
3. Copies the release keystore into `android/app/`.
4. Patches `android/app/build.gradle` to use the release `signingConfig` and
   enables all four `abiFilters` for global device compatibility.
5. Runs `./gradlew assembleRelease`.

## Signing

The release APK is signed with the keystore in `keystore/freeflow-release.keystore`.

| Field | Value |
|-------|-------|
| Alias | `freeflow` |
| Store password | `freeflow2025` |
| Key password | `freeflow2025` |
| Type | PKCS12 |
| Validity | 30 years |
| Schemes | APK Signature v2 + v3 |

This is intentional — the project ships a stable keystore so anyone
distributing the build to their users gets a deterministic certificate and
side-loaded ("force install") installs do not get rejected as parse errors.
To use your own keystore, override the env vars before running the script:

```bash
export FREEFLOW_KEYSTORE_FILE=/abs/path/your.keystore
export FREEFLOW_KEYSTORE_PASSWORD=...
export FREEFLOW_KEY_ALIAS=...
export FREEFLOW_KEY_PASSWORD=...
./scripts/build-apk.sh
```

## Source layout

```
mobile/
├── App.tsx                  # Expo Router entry
├── app.json                 # Expo config (name=Freeflow, package=com.freeflow.app)
├── assets/images/           # Icons (icon / adaptive-icon / splash / favicon)
├── babel.config.js
├── index.tsx                # Native entry point
├── index.web.tsx            # Web entry point (not built into APK)
├── metro.config.js          # Includes @/* path alias + native/web polyfill aliases
├── package.json
├── patches/                 # patch-package overrides (incl. react-native-mmkv C++20)
├── polyfills/               # Platform polyfills (web/native/shared)
├── src/
│   ├── app/                 # Expo Router screens
│   │   ├── (tabs)/          # vps / vpn / history / quick / rebuild
│   │   ├── index.jsx        # Landing
│   │   ├── terminal.jsx
│   │   └── filemanager.jsx
│   ├── components/
│   ├── data/
│   └── utils/
├── scripts/build-apk.sh
└── keystore/freeflow-release.keystore
```

## Notes

- New Architecture (Fabric / TurboModules) is enabled (`newArchEnabled=true`).
- Hermes is enabled.
- Kotlin `2.1.20` is pinned via `expo-build-properties` (required by KSP).
- A patch under `patches/react-native-mmkv+3.3.0.patch` raises the MMKV native
  build to C++20 — required since React Native 0.81 bridging headers use
  C++20 concepts.
