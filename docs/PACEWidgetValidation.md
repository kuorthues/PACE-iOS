# PACE Widget Validation

## Build on macOS

This project has no checked-in shared Xcode scheme or XCTest target. The app target depends on and embeds `PACEWidgetExtension`, so build the app target to validate both products. The project currently sets Xcode 26.6-era settings and an iOS 26.5 deployment target.

From the repository root on a Mac with Xcode installed:

```sh
xcodebuild -resolvePackageDependencies -project PACE.xcodeproj

DERIVED_DATA="$TMPDIR/PACEWidget-DerivedData"
xcodebuild \
  -project PACE.xcodeproj \
  -target PACE \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Confirm that the simulator app contains the extension:

```sh
APP="$TMPDIR/PACEWidget-DerivedData/Build/Products/Debug-iphonesimulator/PACE.app"
test -d "$APP/PlugIns/PACEWidgetExtension.appex"
plutil -lint "$APP/Info.plist"
plutil -lint "$APP/PlugIns/PACEWidgetExtension.appex/Info.plist"
```

`CODE_SIGNING_ALLOWED=NO` is for compilation and bundle inspection. To exercise the App Group and WidgetKit on Simulator, open `PACE.xcodeproj` in Xcode, choose an available iOS Simulator for the PACE app target, configure a development team if Xcode requires one, then run the app. Add PACE from the Home Screen widget gallery. Do not add credentials or signing files to this repository.

## GitHub Actions screenshot

`.github/workflows/pace-simulator-screenshot.yml` builds the app and embedded widget extension on a macOS 26 runner using Xcode 26.6, launches a clean iPhone 17 Pro simulator on iOS 26.5, and uploads `PACE-Welcome-iPhone-17-Pro.png` as the `pace-ios-simulator-screenshot` artifact. It runs on pushes to `feat/ui-ux-redesign` that touch app, widget, shared model, project, or workflow files; it also supports manual dispatch once the workflow is available on the repository's default branch.

The automated image is the signed-out PACE welcome screen. The fresh simulator has no Firebase user or goal data, and the repository has no UI test target or screenshot fixture for authenticated screens. Capturing populated Goals or Widget screens needs deterministic test data and additional UI automation. The artifact is retained for seven days. GitHub-hosted macOS runner usage is free for public repositories and draws from included Actions minutes for private repositories; overage depends on the account plan.

## Simulator and device checklist

Use a test account and record results for both widget sizes.

- Add two PACE widgets and choose different goals; edit one and confirm the other retains its selection.
- Relaunch PACE and restart the Simulator/device; confirm selections persist.
- Create, rename, complete, archive, and delete goals; confirm the choices and rendered state update.
- Create, edit, and delete today's log; verify `LOG TODAY`, `LOGGED TODAY`, and `REST DAY` against each goal's schedule.
- Advance across midnight, a daylight-saving boundary, and a device timezone change; verify the calendar-day countdown and current status.
- For a shared goal, confirm the widget counts only the signed-in member's logs. Remove that member and confirm the widget becomes unavailable.
- Tap a small widget and confirm it opens that goal. Tap a medium widget with proof pending and confirm it opens that goal's logging flow.
- Repeat taps with PACE foregrounded, backgrounded, terminated, and signed out; confirm invalid or inaccessible links are handled without a crash.
- Sign out of account A, sign into account B, and verify no A goal title, progress, or shared-goal metadata appears in B's widgets.
- Check long goal names, VoiceOver labels, and both light/dark system appearance settings.

## Test-target limitation

The repository contains custom in-app test utility files, but no XCTest target, test plan, or checked-in shared scheme that can run them through `xcodebuild test`. The widget metric assertions added to `DailyLoggingTests.swift` cover calendar countdown, streak parity, rest days, midnight status, DST, and timezone changes, but they were not executable from this Windows environment. Run them from a macOS test harness when available, then complete the installation and interaction checklist above.

## Current environment result

The Phase 05 implementation and screenshot workflow were prepared on Windows. `xcodebuild`, `swift`, and `xcrun` are unavailable here, so compilation, package resolution, simulator installation, widget gallery behavior, signing, and device behavior remain unverified. The workflow has not run because it must first be pushed to GitHub. The corrected project references and embedding phase were reviewed in `project.pbxproj`; that inspection is not a substitute for an Xcode build.
