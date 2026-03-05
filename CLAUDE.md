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

The app is a family compliance monitoring tool where all members are equal (no parent/child hierarchy). It tracks screen time, domain access, location, health data, and generates daily scores.

### Targets (defined in `project.yml`)

| Target | Type | Purpose |
|--------|------|---------|
| `BettrFamily` | App | Main app with auth, dashboard, scoring |
| `DeviceActivityMonitorExtension` | Extension | Monitors screen time via FamilyControls |
| `DeviceActivityReportExtension` | Extension | Generates screen time reports |
| `PacketTunnelExtension` | Extension | Local VPN that logs DNS queries for domain tracking |

All targets share code from `Shared/` and use the App Group `group.com.bettrfamily.shared` for data sharing.

### Services (`BettrFamily/Services/`)

Services are `@StateObject`s injected as `@EnvironmentObject` from `BettrFamilyApp.swift`:

- **AuthService** - Firebase Auth (email/password)
- **ScreenTimeService** - FamilyControls/DeviceActivity API
- **VPNStatusMonitor** - Monitors PacketTunnel extension status
- **FirebaseSyncService** - Syncs SwiftData records to Firestore (unsynced records have `syncedToFirebase = false`)
- **FamilyMonitorService** - Monitors other family members' compliance
- **HealthKitService** - Step count, exercise minutes
- **PointsEngine** - Calculates daily scores from activities
- **LocationService** - CoreLocation tracking
- **ActivityConfigService** - Manages monitored app/domain configuration
- **BadgeEngine** - Achievement/badge system
- **HeartbeatService** - BGTaskScheduler-based heartbeats (singleton)

### Data Layer

- **SwiftData** models in `Shared/` (UsageRecord, DomainRecord, ComplianceEvent, DailyScore, Badge, etc.)
- All models have a `syncedToFirebase` flag; `FirebaseSyncService` pushes unsynced records
- **ModelContainer** uses App Group for cross-extension data sharing
- **Firestore** structure: `families/{familyID}/{collection}` for most data; `members/{memberID}` for member profiles

### Shared Constants

`Shared/Constants.swift` contains `AppConstants` with all Firestore collection names, UserDefaults keys, and the App Group ID. Use these instead of hardcoding strings.

## Key Constraints

- Requires `GoogleService-Info.plist` (gitignored) for Firebase
- Requires Apple entitlements: `com.apple.developer.family-controls` and `com.apple.developer.networking.networkextension` (must be requested from Apple)
- Development team: `87N5NSN3D8`
- iPhone only (`TARGETED_DEVICE_FAMILY: "1"`)
