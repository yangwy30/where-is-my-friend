# Where Is My Friend?

一个以隐私为先的 iOS 应用：让彼此同意分享的朋友看到对方**最近所在的城市**，并在朋友们来到同一座城市时收到提醒。

## 产品承诺

> 不追踪实时路线，不默认保存位置历史，只用低功耗方式展示朋友最近所在的城市和更新时间。

首个版本计划包含：

- 使用 Apple 账号登录
- 双向确认的好友关系
- 按好友控制城市共享
- 低功耗后台城市更新
- iOS 主应用与桌面 Widget
- 好友同城通知
- 暂停共享、移除好友、屏蔽用户与删除账号

首个版本明确不做：

- 秒级实时定位
- 精确坐标或地图追踪
- 历史行动轨迹
- 未经双方同意的位置分享
- Android、Web 或商业化功能

## 当前状态

仓库现在包含第一版静态 SwiftUI 原型：

- iOS 18+ SwiftUI App
- Small、Medium、Large WidgetKit 小组件
- Onboarding、朋友、好友详情、邀请、共享和隐私设置页面
- App 与 Widget 共用的 Codable Mock Data 和 App Group 快照存储
- Light/Dark Mode、Dynamic Type 友好的语义化设计系统
- 单元测试和 UI smoke test targets

原型不会请求真实账号、位置、通知或网络权限，也不会上传任何数据。

完整产品路线图见 [PLAN.md](./PLAN.md)，视觉与交互规范见 [docs/DESIGN_SPEC.md](./docs/DESIGN_SPEC.md)。

## 运行原型

1. 使用 Xcode 26 或更新版本打开 `WhereIsMyFriend.xcodeproj`。
2. 选择 `WhereIsMyFriend` scheme 和任意 iPhone Simulator。
3. Build & Run。
4. 完成三步原型 Onboarding 后浏览 App。
5. 在模拟器桌面添加 `Where they are` Widget，切换三种尺寸查看布局。

命令行构建：

```bash
xcodebuild \
  -project WhereIsMyFriend.xcodeproj \
  -scheme WhereIsMyFriend \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 成功标准

- 用户能在 5 分钟内完成登录、加好友和共享设置
- Widget 能清楚显示城市、更新时间和过期状态
- 城市变化在 iOS 允许的后台机会出现后可靠上传
- 同城提醒不重复、不泄露精确位置
- 用户能随时暂停共享并在 App 内发起完整账号删除
- 真机测试、TestFlight 和 App Review 全部通过后才公开发布
