# Building & Running CampusFix

## Prerequisites
- Flutter 3.41.x (stable), Dart 3.11.x
- **CocoaPods needs a UTF-8 locale.** This shell/CI environment defaults to ASCII-8BIT, which makes
  `pod install` crash (`Encoding::CompatibilityError`). Always export before any iOS build:
  ```bash
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  ```
  (Add it to your shell profile to make it permanent.)

## Core & design (pure Dart / Flutter packages) — all green
```bash
cd packages/campusfix_core && dart test        # 651 tests
cd packages/campusfix_design && flutter test   # 232 tests
cd apps/mobile && flutter test                 # mobile widget/flow tests
```

## Admin web
```bash
cd apps/admin && flutter run -d chrome
```

## Mobile app

### iOS simulator — WORKS (with an Apple-Silicon workaround)
```bash
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8   # CocoaPods needs UTF-8
flutter build ios --simulator --debug        # ✓ Built build/ios/iphonesimulator/Runner.app
# or run it on a booted simulator:
flutter run
```
**Root cause of the old `App.framework: No such file` failure (now fixed):** on Apple Silicon,
`flutter build ios --simulator` builds a **universal** slice (`-dIosArchs=arm64 x86_64`). Flutter 3.41's
`thinFramework` then runs `lipo <Flutter.framework/Flutter> -verify_arch arm64 x86_64`, which **Xcode 27's
`lipo` rejects** with `-verify_arch requires exactly one input file`. So `debug_unpack_ios` fails,
`App.framework` is never produced, and the embed step errors on the missing framework. (It is a
Flutter-tool / Xcode-27 `lipo` incompatibility, not an app bug — the Dart compiled fine.)

**Fix (in-repo):** build the simulator slice for **arm64 only** so the `lipo` call becomes
`-verify_arch arm64` (one arch), which succeeds. This is set via
`EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64` in `ios/Flutter/Debug.xcconfig` and `Release.xcconfig`
(Runner target) and in `ios/Podfile` `post_install` (pods). Deployment target stays pinned to iOS 15.0.
**Caveat:** arm64-only simulator builds won't run on an **Intel** Mac's simulator; drop the
`EXCLUDED_ARCHS` lines there (or upgrade to a Flutter version whose `thinFramework` handles Xcode 27's
`lipo`). Verified: the app builds and launches on the iPhone 16 Pro simulator.

### Android
Not yet verified in this environment.
