# F04 / F05 / F07 — Complete

2026-09-28。三项均已实现，并完成相关测试及实际截图检查。F01/F03 的已有修复继续保留。

## F04：隐私摘要

- 中英文摘要增加个人出行计划、共同旅行、同行成员与邀请、航班及航线、同城事件与停留时段。
- 明确区分设备坐标/GPS 移动轨迹与用户主动添加的航班路线。
- 删除账户摘要及生产模式确认文案说明：个人计划等账号数据会被删除，共同旅行中的成员姓名和已添加航班可能继续为其他成员保留；不希望航班被保留时，应先删除自己的航班。
- 保留完整隐私政策入口。

核对依据：[删除账户接口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/supabase/functions/api/index.ts:439)、[共同旅行数据外键](/Users/wangyang/.gemini/antigravity/where_is_my_friend/supabase/migrations/20260906010000_unified_trips_foundation.sql:28)、[个人计划随账户删除](/Users/wangyang/.gemini/antigravity/where_is_my_friend/supabase/migrations/20260911010000_personal_travel_plans.sql:3)、[现有隐私政策](/Users/wangyang/.gemini/antigravity/where_is_my_friend/site/privacy/index.html:258)。这次更新的是 App 摘要与提示文案，未更改后端保留规则。

## F05：深色按钮对比度

- 新增 `onFresh` / `onDestructive` 语义文字颜色：浅色主题用白字，深色主题用深色字。
- 应用于首次定位按钮、好友请求接受按钮、允许通知按钮，以及首页请求数角标。
- 纯色主题配色计算：定位按钮浅色约 5.72:1，深色由原先约 1.48:1 提升至约 12.98:1；角标浅色约 5.23:1、深色约 7.89:1。
- 单元测试验证两套配色均达到 4.5:1；模拟器截图核对实际浅深色文字。以上数值针对主题纯色组合，不将玻璃效果的每个像素当作同一背景。

## F07：本次停留与过去到访分开

- 当前时长只采用同一好友、同一城市的最新有效活动 session，历史事件不再参与起算。
- 没有活动 session 时显示“最近同城”和城市更新时间，不从旧记录推算持续时间。
- 上一次到访保留在历史中。本次事件只有在所有参与者的当前 session 都覆盖该事件时间时，才从过去记录中排除。
- 去重按事件 ID 处理；同一天的不同到访不会再被 24 小时时间窗口合并。
- 时长每分钟以及回到前台时更新。

实测样例：“当前开始于 1 小时前，上次事件在 7 天前”。页面现在显示本次 1 小时，并把 7 天前的事件单独列在过去记录中。

## 验证结果

| 批次 | 结果 |
| --- | --- |
| 逻辑、对比度及主界面回归 | 11/12 初轮通过 |
| 小屏浅深色与中英文隐私页面 | 2/2 通过 |
| iOS 27 隐私页面复测 | 1/1 通过 |

13 个不同相关用例均有通过记录。累计 15 次执行中保留 1 次初轮失败：测试将政策链接只按按钮查找，现已改为查找实际可访问元素并滚动确认可用。App 页面本身无需因此更改。

7 个历史逻辑用例覆盖重复到访、最新有效 session、缺少 session、多人事件、同日不同到访、重复 ID、未来时间及城市不匹配；颜色测试覆盖浅深色的强调色和角标。实际 UI 验证包含英文、中文、重复到访、无当前 session、账号删除失败，以及 iPhone SE 第三代上的浅深色显示。

仅使用本地 Demo 和受控样例，没有删除生产账户或发送真实邀请。详见 [结构化结果](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/results.json)。

## 实际截图

- [中文隐私摘要](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/evidence/small/F04-privacyMomentsSummary-zh-Hans.png)
- [删除后的共同旅行保留说明](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/evidence/small/F04-privacySharedTripRetention-zh-Hans.png)
- [深色定位按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/evidence/small/F05-location-nightJadeAppearance.png)
- [深色好友请求按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/evidence/small/F05-request-button-nightJadeAppearance.png)
- [本次 1 小时与上次到访分开显示](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/evidence/main/F07-repeated-visit-zh-Hans.png)
- [没有当前 session 时的显示](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/evidence/main/F07-no-current-session.png)
