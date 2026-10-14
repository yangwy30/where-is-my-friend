# F01 / F03 修复记录

2026-09-28。已按确认后的首页方案实现，更新中英文文案，并通过 XCTest 检查实际交互与截图。

## F01：首页职责明确

- 删除“你的城市 + 同城人数”的共享设置大卡片。
- 标题下改为不可点击的城市状态；共享暂停时补充状态文字。
- 同城人数、姓名和单人更新时间集中在同城朋友卡，点击展开现有相聚内容。
- 常规共享设置位于“你 → 城市共享”。城市未设置或信息过期时，首页提供针对性的设置/更新入口；既有定位权限提示继续工作。
- 大字号下隐藏同城摘要的装饰图标，并允许文字完整换行。

源码：[首页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift:353)、[同城摘要](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/Components/SameCityMomentCard.swift:82)。

## F03：共享说明反映实际保存状态

| 全局共享 | 单个好友 | 说明 |
| --- | --- | --- |
| 开启 | 开启，有城市 | 对方可以看到最近分享的城市 |
| 开启 | 关闭 | 对方无法看到城市 |
| 暂停 | 开启 | 说明全局已暂停，恢复后才会与此人共享 |
| 暂停 | 关闭 | 对方无法看到城市 |
| 开启 | 开启，城市未设置 | 提示设置城市后才能开始共享 |

恢复全局共享会保留单个好友的选择。文案依据已保存的状态更新，不提前显示尚未保存成功的可见性。

源码：[好友共享说明](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendDetailView.swift:221)。

## 验证

使用 iPhone 18 Pro / iOS 27 和 iPhone SE 第三代 / iOS 26.4.1 的本地 Demo 验证，涉及 14 个不同的相关用例，包含：

- 中英文首页、静态城市文字、同城展开与收起、设置菜单入口。
- 中英文共享开关四种组合，以及恢复全局共享后保留逐好友关闭状态。
- 城市未设置时的恢复入口和好友说明。
- 小屏、最大辅助字号、同城/相聚深链接、暂停后的卡片隐藏。
- 定位提示的消失与恢复、手动城市、好友请求接受后的设置入口。

初轮主回归为 13/14，小屏 4/4。唯一初轮失败来自演示城市区域数据尚未进入首屏状态；测试改为明确刷新并等待目标城市后，该用例复测通过。大字号截图检查还发现新增更新时间在两行限制下被省略，已放开辅助字号的行数并再次验证。

最终复核为 3/3，大字号换行复核为 1/1。累计 22 次执行中保留 1 次初轮失败；14 个不同相关用例均有通过记录。

本轮仅修改与这两项有关的 UI、文案、设计说明和回归测试。原始测试结果及复测记录见 [results.json](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/results.json)。

## 实际截图

- [中文首页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/evidence/main/F01-home-zh-Hans.png)
- [中文同城展开](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/evidence/main/F01-same-city-expanded-zh-Hans.png)
- [单个好友关闭共享](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/evidence/main/F03-friend-sharing-off-zh-Hans.png)
- [全局共享暂停](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/evidence/main/F03-global-sharing-paused-zh-Hans.png)
- [小屏状态对照](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/evidence/small/contact-01.jpg)
- [最大字号下完整的同城更新时间](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/evidence/a11y/Friends-accessibility-city-layout.png)

测试仅使用虚构数据；没有发布或修改生产账号。
