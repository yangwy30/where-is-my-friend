# TestFlight 发布手册

这份手册用于把远程 Supabase Staging 版本分发给真实 iPhone 测试者。它不会发布到公开 App Store。

App Store/TestFlight 文案、审核说明、隐私标签建议和公开 URL 统一维护在 [APP_STORE_METADATA.md](./APP_STORE_METADATA.md)。公开隐私政策与支持站点位于 `site/`，由 `Privacy Site` GitHub Pages workflow 部署。

## 当前候选构建

- App：Where Is My Friend Staging
- Bundle ID：`com.yangwy30.whereismyfriend.staging`
- Widget Bundle ID：`com.yangwy30.whereismyfriend.staging.widget`
- 版本：`0.1.0`
- 构建号：`5`
- Scheme：`WhereIsMyFriend Staging`
- Archive 配置：`Staging TestFlight`
- 后端：远程 Supabase Staging
- APNs：production
- Archive（本机临时生成，不提交 Git）：`/tmp/WhereIsMyFriend-Staging-TestFlight-build5.xcarchive`

## 1. 创建 App Store Connect App 记录

Apple 要求先创建 App 记录，之后才能上传构建。打开 [App Store Connect](https://appstoreconnect.apple.com/apps)，点击左上角 `+` → `New App`，填写：

| 字段 | 值 |
| --- | --- |
| Platforms | iOS |
| Name | Where Is My Friend |
| Primary Language | English (U.S.) |
| Bundle ID | `com.yangwy30.whereismyfriend.staging` |
| SKU | `WIF-STAGING-IOS` |
| User Access | Full Access |

如果名称已被占用，只修改 Name，例如 `WIF Friends Staging`；不要修改 Bundle ID。

## 2. 上传构建

App 记录创建后，在仓库根目录运行：

```sh
xcodebuild -exportArchive \
  -archivePath '/tmp/WhereIsMyFriend-Staging-TestFlight-build5.xcarchive' \
  -exportPath '/tmp/WhereIsMyFriend-Staging-TestFlight-build5-upload' \
  -exportOptionsPlist Config/TestFlightUploadOptions.plist \
  -allowProvisioningUpdates
```

上传成功后，Apple 会处理构建。处理完成前，构建可能不会立刻出现在 TestFlight 页面。

## 3. TestFlight 测试信息

### Beta App Description

```text
Where Is My Friend privately shares city-level presence between accepted friends. It never uploads precise coordinates or route history. This beta focuses on Sign in with Apple, friend requests, city sharing, same-city moments, and Home Screen and Lock Screen Widgets.
```

### What to Test

```text
Please test with two different Apple Accounts on two iPhones:

1. On a fresh install, confirm the introduction is clearly separate from Sign in with Apple, no historical notification appears, and successful sign-in does not show a redundant “Done” alert.
2. On the Sharing tab, choose a test city and keep City sharing enabled.
3. Confirm your own username is visible beside your profile, then invite the other tester by username.
4. On the second phone, accept the incoming friend request. Confirm the row shows progress, disappears, and the new friend appears without requiring a restart.
5. Confirm that each phone sees only the other person's shared city and update time—not precise coordinates.
6. Set both phones to the same test city and confirm a same-city moment appears in the notification history.
7. Add the Widget to the Home Screen and confirm friend/city data appears and respects the selected Widget privacy mode.
8. Add both Lock Screen Widget shapes. Confirm the rectangular Widget shows only friend names and cities, and the circular Widget shows the same-city count and city abbreviation.
9. Long-press a Home Screen or rectangular Lock Screen Widget, choose Edit Widget, and select first and second friends. Confirm those friends move to the front.
10. Switch Widget privacy to Hide names and Hide all, then confirm both Lock Screen Widgets update without leaking hidden details.
11. Force-quit and reopen the app; confirm the Apple session, shared city, friend state, and Widget choices remain available.

Please report which step failed, the iPhone model, iOS version, and a screenshot when possible.
```

### Review Notes

```text
Sign in with Apple is the only authentication method. The reviewer can create a new account directly in the app; no demo credentials are required.

The product stores and shares city-level presence only. Precise coordinates and route history are not uploaded. A user can pause sharing, remove a friend, block a user, sign out, or delete the account from the app.
```

填写一个可接收邮件的 Feedback Email 和 Review Contact。不要把私人手机号或邮箱提交到 Git。

## 4. 邀请另一位 iPhone 用户

对方不需要加入你的 Apple Developer Team。

1. 先在 TestFlight 中创建一个 Internal Testing group。
2. 再创建 External Testing group，例如 `Friends Alpha`。
3. 把构建 `0.1.0 (5)` 加进外部组，粘贴上面的 What to Test。
4. 提交 TestFlight App Review。
5. Apple 批准后，通过对方的邮箱邀请，或创建有限人数的 Public Link。
6. 对方在自己的 iPhone 安装 Apple 的 TestFlight App，接受邀请并安装构建。

首次外部测试通常需要 Beta App Review。后续同版本构建可能不需要完整复审。

## 5. 同城通知当前状态

构建已具备 production Push entitlement，App 会注册 production device token。远程 Staging 的 production Bundle ID、APNs Edge Function secrets 和每分钟执行的 `push-worker` Cron 已配置，定时调用已返回 HTTP 200。

接下来要用两台真实 iPhone 做端到端验收：双方成为好友、打开通知、共享同一城市，并确认系统通知横幅只出现一次。APNs 凭证属于敏感数据，只能保存在 Supabase Edge Function secrets 中，不能提交到仓库或放进 iOS App。

## 6. 每次上传新构建

同一个版本再次上传前，把 App 和 Widget 的 `CURRENT_PROJECT_VERSION` 同时递增。版本号可以继续保持 `0.1.0`，直到需要开启新的 TestFlight 版本线。

官方参考：

- [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
