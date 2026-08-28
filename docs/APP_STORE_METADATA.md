# App Store and TestFlight metadata

Prepared for **Across Us 0.1.0 (Build 6)** on August 27, 2026.

## URLs

- Marketing URL: `https://yangwy30.github.io/where-is-my-friend/`
- Support URL: `https://yangwy30.github.io/where-is-my-friend/support/`
- Privacy Policy URL: `https://yangwy30.github.io/where-is-my-friend/privacy/`
- User Privacy Choices URL: `https://yangwy30.github.io/where-is-my-friend/privacy/#english`

The privacy and support URLs become public after this branch is merged to `main`, GitHub Pages is configured to use **GitHub Actions**, and the **Privacy Site** workflow succeeds.

## English (U.S.) App Store listing

### Name

Across Us

### Subtitle

Friends, city by city

### Promotional text

Stay loosely connected across cities. Share only your latest city with accepted friends, keep precise coordinates private, and glance from a Widget.

### Description

Across Us helps close friends stay connected across cities—without turning friendship into live tracking.

After both people accept a friend request, you can see each other’s latest shared city and update time. Add the Widget to your Home Screen for an at-a-glance view. When eligible friends share the same city, the app can create a same-city moment and notify you.

BUILT FOR MUTUAL SHARING

• Send and accept friend requests using a unique username
• Share only with accepted friends
• Pause sharing globally or for an individual friend
• Remove or block someone whenever you choose

CITY-LEVEL, NOT LIVE TRACKING

• Precise coordinates are processed on your iPhone to determine a city
• The server receives the city and update time—not precise coordinates or routes
• Your current city replaces the previous one; the app does not build a location trail
• Enter a city manually if you prefer not to grant location access

DESIGNED FOR A QUICK GLANCE

• Small, medium, and large Home Screen Widgets
• Compact rectangular and circular Lock Screen Widgets
• Optional per-Widget friend selection
• Freshness indicators show when a city was last updated
• Three Widget privacy modes: full details, hidden names, or fully private
• Same-city moments and configurable notification previews

YOU STAY IN CONTROL

• Sign in securely with Apple
• Control location, background refresh, and notifications separately
• Review blocked people and privacy details in the app
• Delete your account and associated server data from the You tab

Background city updates are opportunistic and controlled by iOS, device settings, connectivity, and permission choices. They are not continuous or guaranteed to be instant.

### Keywords

friends,city,widget,location,travel,social,nearby,sharing,reunion

### What’s New — 0.1.0

Welcome to the first Across Us beta.

• Sign in with Apple and persistent sessions
• Mutual friend requests and per-friend city sharing
• Manual and on-device city updates without uploading precise coordinates
• Home Screen and Lock Screen Widgets with three privacy modes
• Same-city moments, notification controls, and delivery registration
• Profile editing, blocking, favorites, offline retry, and account deletion
• In-app access to the full Privacy Policy and support information

## 简体中文 App Store 本地化

### 名称

Across Us

### 副标题

朋友在哪座城市

### 宣传文本

与分散在不同城市的朋友保持轻松联系。只和已接受的好友共享最近城市，在小组件上一眼查看，同时让精确坐标留在设备上。

### 描述

Across Us 帮助亲近的朋友跨越城市保持联系，同时不会把友情变成实时定位。

双方接受好友请求后，就能看到彼此最近共享的城市和更新时间。把小组件放在主屏幕上，即可快速查看。当符合条件的好友共享同一座城市时，App 可以创建同城时刻并通知你。

双向同意后才共享

• 通过唯一用户名发送和接受好友请求
• 只与已接受的好友共享
• 可以暂停全部共享，或单独调整某位好友
• 随时移除或屏蔽用户

城市级位置，而非实时追踪

• 精确坐标只在 iPhone 上用于判断城市
• 服务器接收城市和更新时间，不接收精确坐标或路线
• 新的当前城市会替换旧记录，App 不会建立行动轨迹
• 如果不想授权定位，也可以手动输入城市

一眼就能看懂

• 小、中、大三种主屏幕小组件
• 清楚显示城市信息的新鲜程度和更新时间
• 三档小组件隐私：完整显示、隐藏姓名、全部隐藏
• 同城时刻和可配置的通知预览

控制权始终属于你

• 通过 Apple 安全登录
• 分别控制定位、后台刷新和通知
• 在 App 内查看屏蔽名单与隐私说明
• 在“你”页面删除账号及关联的服务器数据

后台城市更新由 iOS 根据设备设置、网络和权限择机执行，并非持续运行，也不保证即时更新。

### 关键词

朋友,城市,小组件,位置,旅行,社交,附近,共享,同城

### 版本更新说明 — 0.1.0

欢迎体验 Across Us 的第一个测试版本。

• 通过 Apple 登录并保持会话
• 双向好友请求和逐好友城市共享
• 手动或在设备上判断城市，不上传精确坐标
• 小、中、大三种小组件和三档隐私模式
• 同城时刻、通知控制和设备注册
• 资料编辑、屏蔽、收藏、离线重试和账号删除
• 可在 App 内打开完整隐私政策和支持页面

## TestFlight — English (U.S.)

### Beta App Description

Across Us is a privacy-first social utility for sharing your latest city with mutually accepted friends. It includes Sign in with Apple, friend requests, city-level presence, per-friend sharing controls, same-city moments, notification settings, account deletion, and Home Screen and Lock Screen Widgets. Precise coordinates are used on-device to determine a city and are not uploaded to the server.

This beta is intended to validate real two-person friendship and same-city flows on separate iPhones. Background city refresh timing is controlled by iOS and may not be immediate.

### What to Test — Build 6

Thank you for testing Build 6.

1. On a fresh install, confirm the introduction is clearly separate from Sign in with Apple, no historical notification appears, and successful sign-in does not show a redundant “Done” alert. Close and reopen the app, then confirm your session remains active.
2. Pull down repeatedly on the Friends screen, including with a weak or unavailable connection. Confirm no modal error loops appear and saved friends remain visible.
3. On two iPhones, exchange the usernames shown beside each profile. Send a friend request, accept it on the other phone, and confirm the row shows progress, disappears, and the friend appears on both devices without a restart.
4. Set the same city on both phones from the Sharing tab. Refresh and confirm the shared city and same-city moment appear without exposing precise coordinates.
5. Change per-friend sharing, pause all sharing, remove a friend, and block/unblock a user. Confirm the other phone no longer sees data it should not receive.
6. Add each Home Screen and Lock Screen Widget size, choose preferred friends with Edit Widget, and try Full details, Hide names, and Hide all privacy modes.
7. Open You → Notifications and verify permission state, registration status, and same-city history. Confirm a real same-city notification appears only once.
8. Open You → Privacy & data and verify the public Privacy Policy link.
9. Only on a disposable beta account, test You → Delete account and confirm the app returns to Sign in with Apple and cached Widget data disappears.

Please send screenshots and diagnostics through TestFlight feedback. Do not include precise locations, authentication tokens, or other sensitive information.

### TestFlight Review Notes

Sign-in is required and uses the reviewer’s own Sign in with Apple account; no shared test credentials are needed.

Core review path:
1. Sign in with Apple.
2. The app creates a username automatically; it can be edited from You → Edit.
3. Use Sharing to enter a test city manually without granting location access, or grant location access to determine the city on-device.
4. Friend requests require a second signed-in account on another iPhone. The app remains fully navigable with an empty friend list.
5. Privacy controls are under Sharing and You → Privacy & data.
6. In-app account deletion is available at You → Delete account and removes the Supabase Auth identity and associated app data.

The app intentionally does not provide live maps, continuous tracking, precise-coordinate upload, route history, phone contact import, advertising, or cross-app tracking. Background city updates and push delivery depend on iOS scheduling, permissions, connectivity, and APNs.

### Sign-in required

Select **Yes**. Do not provide a demo username/password because the only production authentication method is Sign in with Apple. Explain this in Review Notes as above.

## Suggested App Privacy answers

Confirm these answers again immediately before App Store submission if the implementation changes.

| Data type | Linked to identity | Tracking | Purpose |
| --- | --- | --- | --- |
| Name | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality |
| Device ID / APNs registration | Yes | No | App Functionality |
| Coarse Location | Yes | No | App Functionality |
| Contacts (the in-app friend graph only; no address-book import) | Yes | No | App Functionality |

Do not select Precise Location, Advertising Data, Diagnostics, or third-party tracking unless a later build actually begins collecting them. App Store Connect answers must include Apple, Supabase, and any other third-party SDK behavior present in the submitted binary.
