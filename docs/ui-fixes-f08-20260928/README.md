# F08 — Complete

> 后续变更：用户在第二批修复中要求新计划默认分享给当前全部好友，并允许逐个取消。该规则已实现，取代本记录中的“新草稿默认仅自己可见”；已有计划保持原选择。见 [第二批记录](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留 F08 首轮的历史证据。

2026-09-28。A「清晰分工」已实现；10 个不同相关用例均有通过记录。

依据另一 chat「审查个人计划与共同旅行边界」的中英文原型，以及用户在本 chat 明确选择的 A「清晰分工」方案实现。保留两类功能，统一名称、用途、入口和复制说明。

## 实现范围

- **My travel plans / 我的出行计划**：告诉选定朋友何时在哪座城市。个人页、计划页面和管理入口保持一致。
- **Friends’ travel plans / 好友出行计划**：看好友分享的城市与日期。“我也会去”改为“添加到我的出行计划”。
- **Shared trips / 共同旅行**：底栏、主页面和创建页面说明用途是邀请同行者、协调航班和抵达时间。
- 共同旅行页可进入个人计划；个人计划可返回已有共同旅行标签页。
- 旅行详情可用本次日期创建个人计划。先确认城市，再检查自己的日期和分享对象；空分享对象仍是仅自己可见，提醒默认关闭。
- 草稿显示来源，并说明日期是独立保存的，不会随原旅行自动同步。复制好友计划不会加入共同旅行。
- Demo 的旅行日期导入读取实际保存的旅行列表，刚创建的旅行也能选中。
- 长文案允许换行；好友卡片操作上下排列并保留足够触摸高度；最大字号下的任务入口移除两侧装饰图标，让文字使用整行。

## 验证

使用 iPhone 18 Pro / iOS 27 与 iPhone SE 第三代 / iOS 26.4.1 的 XCTest，覆盖中英文入口、分享设置、取消草稿、旅行创建与重启保留、完成/撤销完成、日期复制及最大字号。测试使用本地 Demo 数据；不发送真实邀请。

回归过程中保留了失败和中断记录，修正后复测：输入旅行名称后的键盘操作顺序；导入入口与既有航班/地图弹层的呈现冲突；一轮测试进程被终止；最大字号下新入口被装饰图标挤窄；一个不可用的日历图标。最终结果以每个用例最后的通过记录为准。

城市确认沿用既有地图解析规则。在线查询 `Tokyo, Japan` 在本次模拟器返回“未找到城市”；日期复制回归清空查询后选择已有 Demo / 最近城市 Tokyo，验证复制、权限与保存行为。这不是线上地图搜索已通过的声明，也未将机场所服务的都市名称直接当作同城匹配身份。

后续更新（2026-09-29）：东京解析与 MapKit 时区来源已修复；在线 `Tokyo, Japan`、`东京 日本`、Paris 和 Palm Springs 查询通过 XCTest，东京在城市选择表单内也已实际选中。以上旧记录保留为 F08 首轮证据，最新结果见 [第三批修复记录](../ui-fixes-wave3-20260929/README.md)。

结构化结果和最终截图随本记录保存。


| 批次 | 通过 / 执行 |
| --- | --- |
| 主流程与复制逻辑 | 6 / 8 |
| 第一轮导入与旅行复测 | 0 / 2 |
| 小屏中英文和最大字号 | 3 / 3 |
| 旅行生命周期与命名复测 | 2 / 3 |
| 独立导入弹层与在线城市查询 | 0 / 1 |
| Demo 城市下的完整复制流程 | 1 / 1 |
| 最终小屏导入和字号复测 | 2 / 2 |

累计 20 次执行，14 次通过、6 次失败或中断记录保留；10 个不同测试方法均有通过结果。最新的两条导入路径在两台设备上都已通过。断言包含：空分享对象、提醒关闭、保存后仅一份个人计划、原旅行仍只有原成员、日期一致、取消第二份草稿不新增计划。

## 界面证据

- [英文共同旅行入口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/final/F08-shared-trips-en.png)
- [中文个人出行计划](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/final/F08-my-travel-plans-zh-Hans.png)
- [好友计划的新按钮与管理入口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/final/F08-friend-travel-plans-en.png)
- [旅行详情的日期复制入口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/refine/F08-trip-copy-entry.png)
- [带来源说明的个人草稿](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/refine/F08-trip-private-draft.png)
- [独立保存说明与分享范围](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/refine/F08-trip-independent-dates.png)
- [刚创建的旅行出现在导入列表](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/refine/F08-import-saved-trip.png)
- [最大字号下的个人计划入口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/evidence/refine/F08-accessibility-personal-plans.png)

[结构化结果](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/results.json)。原始 XCTest 结果包保存在 `/private/tmp/across-us-f08-*.xcresult`，本目录保留可长期查看的截图与汇总。
