# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This project uses **XcodeGen** to generate the Xcode project from `project.yml`:

```bash
xcodegen generate        # Regenerate BettrFamily.xcodeproj
```

**Always run `xcodegen generate` after modifying `project.yml`** (adding targets, dependencies, build settings, etc).

Build from command line:
```bash
xcodebuild -project BettrFamily.xcodeproj -scheme BettrFamily -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Firebase Cloud Functions (optional, requires Blaze plan):
```bash
cd firebase/functions && npm install && npm run build
firebase deploy --only functions
```

## Architecture

**iOS app (Swift 5.9, iOS 17+, SwiftUI + SwiftData)**

The app is a family wellness tool where all members are equal (no parent/child hierarchy). It tracks screen time, domain access, location, health data, and generates daily scores.

### Targets (defined in `project.yml`)

| Target | Type | Purpose |
|--------|------|---------|
| `BettrFamily` | App | Main app with auth, dashboard, scoring |
| `DeviceActivityMonitorExtension` | Extension | Monitors screen time via FamilyControls |
| `DeviceActivityReportExtension` | Extension | Generates screen time reports |
| `PacketTunnelExtension` | Extension | Local VPN that logs DNS queries for domain tracking |

All targets share code from `Shared/` and use the App Group `group.com.bettrfamily.shared` for data sharing.

### App Flow

`BettrFamilyApp.swift` → `RootView` routes based on auth state:
- Not authenticated → `LoginView`
- Authenticated but not onboarded → `SetupView`
- Authenticated + onboarded → `MainTabView`

### Services (`BettrFamily/Services/`)

All services are `@MainActor` `ObservableObject`s, created as `@StateObject` in `BettrFamilyApp` and injected via `@EnvironmentObject`:

- **AuthService** — Firebase Auth (email/password)
- **ScreenTimeService** — FamilyControls/DeviceActivity API
- **VPNStatusMonitor** — Monitors PacketTunnel extension status
- **FirebaseSyncService** — Syncs SwiftData records to Firestore (unsynced records have `syncedToFirebase = false`)
- **FamilyMonitorService** — Monitors other family members' compliance
- **HealthKitService** — Steps, exercise, sleep, stand hours, daylight, workouts, and more from Apple Health
- **PointsEngine** — Calculates daily scores from ActivityRecords; manages streaks
- **LocationService** — CoreLocation tracking
- **ActivityConfigService** — Manages configurable point values per activity type (`FamilyActivityConfig`)
- **BadgeEngine** — Achievement/badge system (26 badges across 4 categories)
- **CalendarService** — EventKit integration for family calendar
- **HeartbeatService** — BGTaskScheduler-based heartbeats (singleton, accessed via `.shared`)

### Data Layer

- **SwiftData** models in `Shared/` (UsageRecord, DomainRecord, ComplianceEvent, DailyScore, Badge, ActivityRecord, StreakRecord, LocationSnapshot, ProximityEvent, RaveEvent, FamilyMember, ActivityConfig)
- All models have a `syncedToFirebase` flag; `FirebaseSyncService` pushes unsynced records
- Models expose a `firestoreData` computed property (`[String: Any]`) for Firestore serialization
- **ModelContainer** uses App Group for cross-extension data sharing
- **Firestore** structure: `families/{familyID}/{collection}` for most data; `members/{memberID}` for member profiles
- **UserDefaults.shared** is the App Group `UserDefaults` (extension in `Shared/Constants.swift`)

### Scoring System

`PointsEngine` calculates scores from `ActivityRecord`s grouped by category:
- **positive** — Steps, walking distance, workouts, sleep, exercise
- **bad** — Excessive screen time (>2h), social media, streaming, gaming, late-night screen
- **bonus** — Family proximity, RAVEs from other members, manual activities (chores)

Streak multiplier: 2 days = 1.5x, 7 days = 2.0x, 30+ days = 3.0x

### Shared Constants

`Shared/Constants.swift` contains `AppConstants` with all Firestore collection names, UserDefaults keys, and the App Group ID. Use these instead of hardcoding strings.

## Key Constraints

- Requires `GoogleService-Info.plist` (gitignored) for Firebase
- Requires Apple entitlements: `com.apple.developer.family-controls` and `com.apple.developer.networking.networkextension` (must be requested from Apple)
- Screen Time APIs require a **physical device** (not simulator)
- Development team: `87N5NSN3D8`
- iPhone only (`TARGETED_DEVICE_FAMILY: "1"`)
