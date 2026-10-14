# UI 修复第三批 — Complete

范围：F14、城市搜索、F10、F24、F16。2026-09-29 完成本地实现与验证。本批已于 2026-09-29 随 TestFlight **1.0.6（27）** 发布，Apple 处理完成并关联内部测试组。见 [发布记录](../releases/1.0.6-27/README.md)。

## 改动

- **F14**：仅将 Apple 授权域中的 `canceled` 视为用户退出。结束等待并清理 nonce，不显示失败提示；真正失败继续提示。
- **城市搜索**：使用 MapKit 地点本身提供的时区，修复东京结果没有 locality 而被过滤的问题。兼容范围限定为日本、东京行政区、东京时区和准确的东京名称；不把任意省、州、机场直接当作城市。保留新宿、成田等明确的 locality。个人计划、旅行日期导入与手动城市选择共用此搜索。
- **F10**：收到的好友请求放在首位，进入页面刷新请求；用户名、分享邀请和发送邀请随后显示。处理完请求后恢复邀请内容为首项。
- **F24**：小型好友 Widget 打开所示好友，中、大型提供逐人链接。App 刷新后按当前账号校验好友，失效链接显示可理解的提示。隐藏身份的 Widget 使用通用入口；聚合同城组件保持聚合入口。锁屏矩形只有一位可见好友时也可直达该好友。
- **F16**：通知页集中提供好友邀请、旅行邀请、同城提醒、计划重叠、航班与行程提醒五类入口。同城提醒可逐人调整，旅行提醒可按行程调整，与旅行页共用同一份状态。系统通知未允许时，明确区分已保存偏好和实际送达，并提供系统授权入口。补齐新文案中文与辅助字号布局。

## 验证边界

- Apple 取消与真实失败使用真实错误类型的单元测试验证，没有操作真实 Apple 账户授权。
- 城市搜索使用在线 MapKit，未用 Demo 城市结果替代东京搜索。
- Widget 逐人 URL 与隐私规则由单元测试验证，App 冷启动、后台打开、失效链接由 XCTest 实际打开 URL 验证；没有宣称完成真机桌面 Widget 安装和点击认证。
- 通知拒绝状态使用 DEBUG 专用 fixture；未改变设备授权，也未发送真实推送。中英文偏好保存操作使用本地 Demo。

## 测试结果

11 个不同 XCTest 用例均有通过记录，覆盖 iPhone 18 Pro / iOS 27.0 与 iPhone SE 第三代 / iOS 26.4.1。累计 25 次执行，20 次通过、5 次初轮失败；最后两批 11 次执行全部通过。

| 批次 | 通过 / 执行 | 主要内容 |
| --- | --- | --- |
| tests2 | 7 / 9 | Apple 错误分类、真实地图查询、隐私 URL、登录边界、东京表单、好友链接 |
| tests3 | 1 / 3 | 请求与通知控件标识复查、好友链接 |
| tests4 | 1 / 2 | 中英文五类入口与同城/旅行开关保存 |
| small | 8 / 8 | 单元测试、小屏请求接受/拒绝、最大辅助字号、旅行键盘保存回归 |
| complete | 3 / 3 | iOS 27 请求处理、完整中英文通知流程、后台/冷启动/失效好友链接 |

初轮发现容器标识覆盖子按钮标识，以及请求入口未刷新时 Demo 请求操作失败；移除覆盖标识、进入页面刷新后通过复测。截图检查补齐旧通知预览、旅行通知标题和航班说明的中文。原始失败记录保留于 `results/`，不是只记录最终成功。

小屏通知好友开关的原生触控区域与文字裁切审计未报告问题；相关入口、系统设置按钮与开关有至少 44pt 的尺寸断言。此结果仅覆盖被检查的屏幕，不是全 App 无障碍认证。应用和 Widget 测试构建成功，`git diff --check` 通过。

原始结果：`/private/tmp/across-wave3-{tests2,tests3,tests4,small,complete}.xcresult`；摘要保存于 `results/`，本目录共保存 28 张过程截图。`first` 和 `final` 为中间轮次，最新通知文案以 `complete` 为准。

## 实际界面

- [真实东京搜索结果](evidence/first/W3-city-live-Tokyo-result.png)
- [请求置顶](evidence/complete/W3-F10-request-first.png) / [处理完成后的邀请入口](evidence/complete/W3-F10-invite-after-response.png)
- [中文通知总览](evidence/complete/W3-F16-overview-zh-Hans.png)
- [逐人同城提醒](evidence/complete/W3-F16-same-city-zh-Hans.png) / [旅行提醒与系统权限说明](evidence/complete/W3-F16-trip-settings-zh-Hans.png)
- [小屏最大字号入口](evidence/small/W3-F16-large-overview-zh.png) / [逐人开关](evidence/small/W3-F16-large-friends-zh.png)
- [后台打开好友](evidence/complete/W3-F24-warm-Lin.png) / [冷启动打开好友](evidence/complete/W3-F24-cold-Mia.png) / [失效链接](evidence/complete/W3-F24-unavailable.png)
