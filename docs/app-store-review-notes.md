# App Store submission notes — v2.0.0 (build 22)

Last submitted version was **1.0.1**. This is a major bump — the Apple Watch companion
app is a large enough addition (a whole second target, a new permission, a new sync
system) to warrant crossing to 2.0 rather than a minor/patch release.

## 0. Checklist — what actually needs to change in App Store Connect

- [ ] **Version number**: set to `2.0.0`, build `22` (already set in `project.yml` / the
      archive — App Store Connect reads these from the uploaded build automatically).
- [ ] **"What's New in This Version"** release notes — draft below, §1.
- [ ] **App Privacy questionnaire** — re-check the Location row specifically; it's new
      since 1.0.1. See §3.
- [ ] **Screenshots** — both iPhone and Apple Watch screenshot slots need updating (Watch
      screenshots may not have existed at all for 1.0.1 if this is the first Watch
      submission). See §5 for where the finished assets are.
- [ ] **App Review notes field** — paste the note in §4; flag that live HealthKit/GPS
      needs a physical Watch to fully verify.
- [ ] Encryption compliance question should no longer prompt (`ITSAppUsesNonExemptEncryption`
      is now set) — confirm it's actually skipped on this upload.

## 1. Suggested "What's New in This Version" text

> **New: Apple Watch app.** Start and log a workout right from your wrist — 25 activity
> types, live set-by-set logging for weight training, and GPS-tracked route, distance,
> and pace for outdoor activities. Works independently of your phone.
>
> Also in this release: expanded HealthKit data sharing (heart rate, calories, and
> distance now sync in both directions), and a number of sync-reliability fixes between
> the Watch and iPhone apps.

## 2. What changed since 1.0.1 (context, not for the listing)

- New `RepPilotWatch` target — full watchOS companion app.
- Watch↔phone sync over `WatchConnectivity`, with durable retry queues on both sides.
- GPS/outdoor tracking on Watch for Running, Cycling, Walking, Hiking, Dancing — new
  `NSLocationWhenInUseUsageDescription` permission (watch-only).
- Expanded HealthKit write access (heart rate, active energy, distance, workout routes),
  not just the workout summary.

## 3. Permissions this build requests, and why

| Key | Target | Reason |
|---|---|---|
| `NSHealthShareUsageDescription` | iOS | Read workouts/HR/calories/distance/route from Apple Health |
| `NSHealthUpdateUsageDescription` | iOS | Save logged workouts back to Apple Health |
| `NSPhotoLibraryUsageDescription` | iOS | Attach a photo to a logged workout |
| `NSCameraUsageDescription` | iOS | Take a photo to attach to a workout |
| `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` | watchOS | Record a live `HKWorkoutSession` on the wrist |
| `NSLocationWhenInUseUsageDescription` | watchOS only | GPS route/distance/pace for outdoor types (Running, Cycling, Walking, Hiking, Dancing) — **new in this build**. No location usage on the iOS target at all. |

No accounts, no backend, no network calls other than Apple's own HealthKit/Health app —
everything is stored locally via SwiftData. This matters for the App Privacy answers below.

## 4. App Privacy (App Store Connect → App Privacy questionnaire)

Since there's no backend and nothing is transmitted off-device (Health data stays within
Apple's HealthKit, never sent anywhere by this app):

- **Health & Fitness** (workouts, heart rate, etc.): collected → **Yes**, but:
  - Used for: App Functionality only.
  - Linked to identity: **No** (no account system).
  - Used for tracking: **No**.
- **Location** (watch only, When-In-Use, outdoor workout types): collected → **Yes**, same
  answers as above (App Functionality only, not linked, no tracking).
- **Photos**: only if the user chooses to attach one; same answers (App Functionality only,
  not linked to identity in a way that leaves the device, no tracking).
- Everything else (contact info, browsing history, purchases, etc.): **No data collected**.

`ITSAppUsesNonExemptEncryption: false` is now set in `project.yml`, so App Store Connect
should no longer prompt the export-compliance question on each upload.

## 5. Notes for the App Review team (paste into the "Notes" field)

> This build adds an Apple Watch companion app for live, set-by-set workout logging and
> GPS-tracked outdoor activities (Running, Cycling, Walking, Hiking, Dancing). The watch
> app runs independently of the phone (`WKRunsIndependentlyOfCompanionApp`) — no phone
> pairing is required to start and record a workout.
>
> Live HealthKit recording and GPS route capture depend on physical sensors and are best
> verified on a real Apple Watch rather than Simulator. If reviewing on Simulator, the
> watch app's navigation and set-logging UI are fully testable; workout data will simply
> lack real heart-rate/GPS samples.
>
> No account or sign-in is required anywhere in the app.

## 6. Screenshots

Finished, framed marketing screenshots (ready to upload) are in
`~/Desktop/RepPilot Screenshots/Marketing/` — 6 iPhone + 5 Apple Watch, each with a
device frame and headline. Raw (unframed) device screenshots are alongside in `iPhone/`
and `Watch/` in the same folder, in case App Store Connect's exact per-size-class
requirements need a plain, uncaptioned version instead.

Generated via a debug-only, `-UITestDemoTour`/`-UITestDemoData` launch-argument-gated demo
data seeder (`RepPilot/Services/DemoDataSeeder.swift`, `RepPilotWatch/DemoTour.swift`) —
both are compiled out of Release builds entirely (`#if DEBUG`), so none of this ships.
Regenerate any time with:

```sh
# iPhone — drives the real app via XCUITest, exports from the .xcresult
xcodebuild test -scheme RepPilot -destination "id=<SIMULATOR_UDID>" -only-testing:RepPilotUITests
xcrun xcresulttool export attachments --path <path-to-.xcresult> --output-path <dir>

# Watch — no watchOS UI-test target exists, so this launches with a scripted,
# timer-driven screen sequence (DemoTour) and polls `xcrun simctl io screenshot`
# on a matching schedule; see DemoTour.swift's inline timings.
xcrun simctl launch <WATCH_UDID> com.repilot.rep-pilot.watchkitapp -UITestDemoTour
```

The marketing-frame layer (device bezel + headline compositing) lives in
`/private/tmp/.../scratchpad/marketing/generate.py` in the session that built it — not
checked into the repo, since it's a one-off asset generator, not app code. Re-run it (or
ask Claude to regenerate) if the underlying screenshots change.

iPhone 14 Plus (`CD0A414C-88CD-4F87-849A-D9FB4D65A3AF`) is this project's standard
screenshot/review simulator.
