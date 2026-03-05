# BettrFamily

A family wellness app for iOS that promotes healthy habits through transparency, not control. All family members are equal — there are no parent/child roles.

## What it does

- **Daily Scores** — Earn points for healthy activities (steps, exercise, sleep) and lose points for excessive screen time, social media, or late-night usage
- **Screen Time Monitoring** — Tracks app usage via Apple's FamilyControls/DeviceActivity APIs
- **DNS Monitoring** — A local VPN logs which domains are accessed (traffic is not intercepted or redirected)
- **HealthKit Integration** — Reads steps, distance, workouts, sleep, stand hours, and more from Apple Health
- **RAVE System** — Recognize And Value Everyone: family members can award bonus points to each other for positive actions (cooking, cleaning, being kind)
- **Manual Activities** — Log household chores like cooking, vacuuming, or grocery shopping for bonus points
- **Badges & Streaks** — 26 achievements across streak, activity, social, and milestone categories with streak multipliers
- **Family Calendar** — Shows upcoming events from the shared iCloud Family calendar
- **Compliance Events** — Transparent alerts when VPN is disabled, heartbeats are missing, or monitored apps are used
- **Family Leaderboard** — See how all family members are doing today and over the past week

## Tech Stack

- **iOS 17+**, Swift 5.9, SwiftUI, SwiftData
- **Firebase** — Auth, Firestore, Cloud Messaging (FCM)
- **Apple Frameworks** — FamilyControls, DeviceActivity, NetworkExtension, HealthKit, EventKit, CoreLocation, CoreBluetooth
- **XcodeGen** — Xcode project generated from `project.yml`

## Project Structure

```
BettrFamily/                  # Main app target
  Services/                   # App services (auth, sync, points, health, etc.)
  Views/                      # SwiftUI views
Shared/                       # Models & constants shared across all targets
DeviceActivityMonitorExtension/   # Screen time monitoring extension
DeviceActivityReportExtension/    # Screen time report extension
PacketTunnelExtension/            # Local VPN for DNS logging
firebase/                     # Cloud Functions, Firestore rules & indexes
```

## Setup

### Prerequisites

- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A Firebase project with Auth, Firestore, and FCM enabled
- Apple Developer account with the following entitlements (must be requested from Apple):
  - `com.apple.developer.family-controls`
  - `com.apple.developer.networking.networkextension` (packet-tunnel-provider)

### Getting Started

1. Clone the repo
2. Add your `GoogleService-Info.plist` to `BettrFamily/` (gitignored)
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. Open `BettrFamily.xcodeproj` in Xcode
5. Select your development team and run on a physical device (Screen Time APIs require a real device)

### Firebase Cloud Functions (Optional)

The app works entirely on-device using Firestore listeners and local notifications. Cloud Functions are only needed for server-side reliability on the Blaze plan:

```bash
cd firebase/functions
npm install
npm run build
firebase deploy --only functions
```

## How Scoring Works

| Category | Examples | Points |
|----------|----------|--------|
| Positive | Steps (1pt/1000), walking (2pt/km), workouts (3pt each), good sleep (5pt) | + |
| Negative | Excessive screen time (-1pt/30min >2h), social media (-2pt/30min), streaming (-1pt/30min), late night screen (-3pt) | - |
| Bonus | Family proximity, RAVEs from other members, manual activities | + |

**Streak multiplier**: 2 days = 1.5x, 7 days = 2.0x, 30+ days = 3.0x

## License

Private repository. All rights reserved.
