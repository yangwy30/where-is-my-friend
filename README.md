# 📍 Where's My Friend

> An iOS location-sharing social app built with SwiftUI, Firebase, CoreLocation (Significant Location Change), and WidgetKit. Know what city your friends are in at a glance, get notified when you arrive in the same city, without draining battery!

---

## 🌟 Key Features

- **🌆 City-Level Location Tracking**: Low-power background updates using CoreLocation Significant Location Change monitoring (~500m threshold). Never exposes precise coordinates to friends.
- **📱 Home Screen Widget**: Medium, Small, and Large WidgetKit widgets to view friends' current cities right on your iOS Home Screen.
- **🎉 Same-City Notifications**: Automatic push notifications delivered via Firebase Cloud Functions + FCM when you and a friend end up in the same city.
- **🤝 Invitation Code Friend System**: Add friends with 6-character invite codes (with a 50-friend soft limit for scalability).
- **🌙 Ghost Mode (Privacy)**: Instantly toggle Ghost Mode to hide your location from friends.
- **🎨 3-Tier Avatar System**: Custom profile photo (Firebase Storage) ➔ Preset Emoji ➔ Initials with custom background color fallback.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS Client App                         │
│  SwiftUI 5 (iOS 17+) | MVVM + Services Layer | @Observable │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
     CoreLocation (SLC)             App Group Shared Defaults
               │                              │
               ▼                              ▼
      Firebase Firestore              WidgetKit Extension
               │                              (Home Screen)
               ▼
     Firebase Cloud Functions ───► FCM Push Notifications
```

---

## 📁 Repository Structure

```text
where-is-my-friend/
├── WhereIsMyFriend/
│   ├── App/                   # App entry, AppDelegate, App lifecycle
│   ├── Core/
│   │   ├── Services/          # Location, Auth, Firestore, Geocoding, WidgetData
│   │   ├── Models/            # AppUser, Friendship, FriendLocation
│   │   └── Extensions/        # CountryFlag, Color+Hex, Date+Relative
│   ├── Features/
│   │   ├── Auth/              # LoginView, SignUpView, AuthViewModel
│   │   ├── Friends/           # FriendsListView, AddFriendView, FriendRequestsView
│   │   ├── Onboarding/        # Onboarding flow & permission explanation
│   │   ├── Profile/           # ProfileView & avatar configuration
│   │   └── Settings/          # SettingsView & Ghost Mode toggle
│   ├── Shared/                # Data models shared with Widget target
│   └── Resources/             # Assets, Info.plist
├── WhereIsMyFriendWidget/     # WidgetKit extension target
├── CloudFunctions/            # Node.js Firebase Cloud Functions (Same-city push)
├── MASTER_PLAN.md             # Complete master implementation doc
└── README.md
```

---

## 🚀 Setup & Installation

### Prerequisites

- Xcode 16.0+
- iOS 17.0+ deployment target
- Apple Developer Account (for Push Notifications & App Groups)
- Firebase Project with Auth, Firestore, Cloud Messaging & Storage

### Step 1: Firebase Configuration

1. Download `GoogleService-Info.plist` from your Firebase Console.
2. Add `GoogleService-Info.plist` to `WhereIsMyFriend/Resources/`.

### Step 2: Xcode Project Capabilities

Enable the following capabilities in your Xcode Target:
- **Background Modes**: `Location updates`, `Remote notifications`
- **Push Notifications**
- **App Groups**: `group.com.yourname.whereismyfriend`
- **Sign in with Apple**

### Step 3: Deploy Cloud Functions

```bash
cd CloudFunctions
npm install
firebase deploy --only functions
```

---

## 🛡️ License

MIT License. Designed and built with ❤️.
