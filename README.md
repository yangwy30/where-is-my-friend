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

仓库现在包含可完整操作的 SwiftUI 离线 MVP：

- iOS 18+ SwiftUI App
- Small、Medium、Large WidgetKit 小组件
- Onboarding、朋友、好友详情、邀请、共享和隐私设置页面
- App 与 Widget 共用的 Codable Mock Data 和 App Group 快照存储
- Light/Dark Mode、Dynamic Type 友好的语义化设计系统
- 单元测试和 UI 交互测试 targets

- 本地持久化 Demo Repository 与可替换的 `AppRepository` 边界
- Demo 登录、Sign in with Apple 客户端授权与远端 token 交换接口
- 好友邀请、接受、拒绝、移除、收藏与逐好友共享设置
- 手动测试城市、前台定位、Visits、Significant Location Change
- 同城事件去重、本地通知预览与通知历史
- App Group Widget 快照、登出清除和真实更新时间
- Demo Lab 场景模拟、REST API adapter、Keychain session token
- 资料编辑、邀请 Deep Link、屏蔽与解除屏蔽
- 城市标准化、同城进入/离开状态与六小时重新进入冷却
- 离线位置/Push Token 队列、指数退避重试与可见同步状态
- Widget 三档隐私模式：完整、隐藏姓名、全部隐藏
- Debug、Staging、Release 分离；非 Debug 构建在无真实 API 时安全关闭

没有真实 Server 时，Debug App 默认使用 Local Demo Repository。所有业务交互都会本地保存；选择 Server 后只需实现 [API contract](./docs/API_CONTRACT.md)，无需重写 SwiftUI 页面。Staging 和 Release 不允许回退到 Demo 数据。

App 只会在用户主动点击相关控制后请求位置或通知权限。本地 Demo 模式不会上传任何数据；Sign in with Apple 的真实 token 交换与网络请求仅在配置 Remote API 后启用。

完整产品路线图见 [PLAN.md](./PLAN.md)，视觉与交互规范见 [docs/DESIGN_SPEC.md](./docs/DESIGN_SPEC.md)。

生产接入资料：

- [客户端架构决策](./docs/ADR-001-CLIENT-BOUNDARY.md)
- [REST API 合同](./docs/API_CONTRACT.md)
- [PostgreSQL 参考 schema](./docs/DATABASE_SCHEMA.sql)
- [真实后端接入清单](./docs/REAL_BACKEND_CHECKLIST.md)

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
