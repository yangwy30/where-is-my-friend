# UI 修复第二批 — Complete

2026-09-28。以下九项及新的默认分享行为均已完成实现与验证；用户随后授权发布，生产后端及 TestFlight 1.0.6（26）现已就绪。

范围：F09、F11、F19、F20、F21、F22、F26、F28、F30，以及新建出行计划默认选择全部好友。保留前面 F01/F03/F04/F05/F07/F08 的修复。

## 分享范围

- 新建个人计划和复制出的新计划，在编辑器中默认选择当前全部未屏蔽好友，并默认允许他们浏览城市和日期。
- 用户可以逐个取消选择，也可以选择全部或清空选择。保存前展示分享范围；仍需按“保存出行计划”才生效。
- 编辑已保存的计划保留原先的选择，不补选新好友。重叠提醒仍默认关闭。
- 共同旅行的成员关系与个人计划的分享对象分开，复制计划不发送入团邀请、不加入共同旅行。
- 沿用服务端每份计划最多 100 位分享对象的现有上限；超限显示明确提示并禁止保存，不静默截掉好友。

这取代 F08 首轮中的“新草稿默认仅自己可见”规则；F08 的旧截图和测试记录保留为当时版本的历史证据。

## 各项变化

- **F09**：“打个招呼”改为“分享见面邀约”，使用系统分享图标，辅助说明明确选择 App 发送。
- **F11**：待处理的发出邀请可撤回，带确认和操作反馈；本地与远端实现均校验发送方。服务端锁住邀请记录再检查 pending 状态，已经接受的邀请不会删除好友关系。撤回后清理待发送通知，接收方刷新后不能再接受；已经送达系统通知的推送无法收回。
- **F19**：移除好友计划页的大标题和重复副标题，将添加计划入口缩成一行，让第一条计划更早出现。
- **F20**：扩大计划分享/复制、航班清除/查询等触摸区域；航班表单在辅助字号下纵向排列；日历保留完整辅助标签和足够热区。好友卡和同城历史的姓名、城市允许换行。
- **F21**：增加“跟随系统”，作为没有已保存偏好时的默认值，已有明确浅/深选择继续保留。App 与 Widget 都尊重系统外观。
- **F22**：补齐航班查询/无结果/当天日期、自动旅行名、引导按钮、历史分组和简短更新时间的中文；日期范围按当前语言格式化。
- **F26**：保留 F07 的每分钟及前台更新时间；长姓名、城市与历史参与者不再强制一行，辅助字号下减少装饰占位。
- **F28**：旅行保存固定在底部安全区域，键盘展开时也能操作；旅行和航班输入都提供“完成”按钮。
- **F30**：空首页突出“邀请第一位朋友”，直接打开系统分享，同时保留通过用户名添加；隐藏空的好友计划分支。

## 服务端发布依赖

用户随后授权完成发布：`20260929010000_cancel_friend_requests.sql` 已部署，生产 API 已更新至 29，TestFlight 1.0.6（26）已处理完成并关联内部测试组。没有发送真实邀请或删除真实数据。详见 [发布记录](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/releases/1.0.6-26/README.md)。

## 验证

19 个不同 XCTest 用例均有通过记录；27 个不同后端用例通过。XCTest 累计 37 次执行，其中 29 次通过、8 次初轮失败记录保留。

| XCTest 批次 | 通过 / 执行 |
| --- | --- |
| main | 12 / 15 |
| small | 7 / 8 |
| refine | 5 / 6 |
| flight | 0 / 1 |
| flight-final | 1 / 1 |
| final | 3 / 4 |
| empty | 0 / 1 |
| empty-final | 1 / 1 |

- iPhone 18 Pro / iOS 27.0：中英文全选好友与取消选择的持久化、邀请保留/撤回/重发、系统分享关闭、键盘展开时直接保存、真实等待一分钟后的历史时长更新。
- iPhone SE 第三代 / iOS 26.4.1：最大辅助字号、完整航班号、清除/查询/保存热区、日期网格和系统日历、长姓名/城市换行、真实系统深色下的“跟随系统”。
- 原生审计检查触控区域和文字裁切，同时断言相关按钮至少 44pt。目标计划操作、航班操作与日期控件通过。系统对行程标题和姓名仍返回两条保守裁切提示，原始报告保留；实际大字号截图中二者完整显示。未将诊断收集成功表述为全 App 无障碍认证。
- 后端验证发送方权限、禁止接收方/第三方撤回、重复撤回、接受在先时保留好友关系、撤回在先时禁止接受、重发生成新邀请、清理通知队列及使已领取任务失效；并回归旅行分享隔离和认证边界。

初轮失败包含分享面板控件类型变化、旧页面标题选择器、日期网格滚动定位、固定底栏上方的滚动/输入定位，以及空好友数据源与初始演示缓存不一致。相应测试已修正并通过复测；截图检查还发现并修正了航班号省略、底部大字号按钮和遗漏中文标签。


## 实际界面

- [默认全部好友（中文）](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/refine/W2-default-all-friends-zh-Hans.png)
- [取消一位好友后的保存结果](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/refine/W2-saved-audience-zh-Hans.png)
- [精简后的好友计划页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/refine/W2-F19-compact-feed-zh-Hans.png)
- [系统分享面板](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/final/W2-F09-system-share.png)
- [撤回邀请确认](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/final/W2-F11-withdraw-confirmation.png)
- [完整的大字号航班号与按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/flight-final/W2-F20-flight-large-text.png)
- [原生日历和日期网格](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/refine/W2-F20-date-range-large-text.png)
- [跟随系统深色](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/refine/W2-F21-system-home.png)
- [中文创建旅行](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/refine/W2-F22-generated-name-zh.png)
- [中文引导与辅助标签](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/final/W2-F22-onboarding-zh.png)
- [历史长文本](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/small/W2-F26-long-history.png)
- [停留页面后的时间更新](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/main/W2-F26-live-time-update.png)
- [键盘上方直接保存](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/small/W2-F28-keyboard-save.png)
- [邀请第一位朋友](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/evidence/empty-final/W2-F30-first-friend.png)

[XCTest 汇总](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/results.json) · [后端汇总](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/backend-results.json)。原始日志和结果包位于 `/private/tmp/across-us-wave2-*`；本目录保存长期可查看的截图、审计文本和结构化结果。
