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
cd packages/campusfix_design && flutter test   # 224 tests
cd apps/mobile && flutter test                 # mobile widget/flow tests
```

## Admin web
```bash
cd apps/admin && flutter run -d chrome
```

## Mobile app

### iOS simulator — KNOWN BUILD ISSUE (unresolved)
With UTF-8 locale set, `pod install` succeeds and the deployment target is pinned to iOS 15.0
(`ios/Podfile` `post_install` + `Runner.xcodeproj`). However `flutter build ios --simulator --debug`
still fails with:
```
Error (Xcode): .../build/ios/Debug-iphonesimulator/App.framework: (l)stat: No such file or directory
```
Tried without success: `flutter clean` + fresh `pod install`, UTF-8 locale, deployment target 15.0,
Podfile `post_install` override. The app's logic is fully covered by widget/unit tests; this is a
build-pipeline issue (Flutter 3.41 `build ios --simulator` / Xcode), not an app bug. **To resolve:**
try building/running `ios/Runner.xcworkspace` directly in Xcode (it often surfaces the real cause and
regenerates `App.framework`), or `flutter run` from an interactive terminal. Tracked for the S6
integration pass.

### Android
Not yet verified in this environment.
