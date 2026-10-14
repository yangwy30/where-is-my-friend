# Across Us：完整 UI / UX 评审（XCTest 与逐屏视觉检查）

初评日期：2026-09-27；XCTest 实测：2026-09-28（美国西海岸）。

## 评审范围与完成状态

本轮已完成本地可运行版本的主要 UI / UX 评审：在 **iPhone 18 Pro / iOS 27** 和 **iPhone SE 第三代 / iOS 26.4.1** 上运行 XCTest，检查主要操作链路、失败和空状态、大字号、深浅色、中英文、分享范围和 Widget 组件。报告共 **30 项改进建议**，每项区分实际复现、源码事实与设计判断。

累计执行 **90 次测试（含复测），79 次通过、11 次失败记录保留**；导出 **213 张实际截图**。主套件为 61 项，其中 57 项通过、4 项初始失败，均作了对照复核。通过次数包含取证路径正常完成，不代表对应界面没有设计问题。

- 被评审源码基线：`dcb0e2b`。没有保留任何 App 或原有测试源码改动。
- 测试使用本地 Demo。另用可移除的测试样例构造无好友、离线 UI 状态、长姓名和重复到访；这些截图均标明样例条件。
- 临时评审测试与数据设置已从 App 源码移除，复现材料保存在本报告同目录的评审证据文件夹。
- 原始测试包含失败记录；所有失败均作了截图和对照复核，详见 [测试结果与失败归因](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/RUN_RESULTS.md)。不能把“测试脚本跑完”当成“界面没有问题”。
- 完整截图与控件证据见 [截图索引](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/SCREENSHOTS.md)。

**边界：** 真实 Apple 账号授权、APNs 跨设备送达、云端邀请/并发/网络失败、真机后台定位、桌面 Widget 安装与系统刷新、真实 VoiceOver 连续操作未在本轮认证。Widget 的本轮实测在使用与扩展相同视图的预览宿主中进行；其真实桌面点击落点为源码检查。离线截图是状态注入，不是线上断网实测。主观审美与理解成本仍需真实用户验证。

证据类型：**实测**表示 XCTest 实际执行并保存结果；**源码**表示可直接定位实现；**设计判断**表示基于界面和任务提出的改进，不宣称已经测得用户误解率或转化效果。

## 总体判断

Across Us 已有明确的视觉基础：奶油底色、森林绿、城市立体插画、相聚主题和原生导航。值得保留这套辨识度。下一轮应优先处理三个方面：

1. **让动作可预测。** 点击前理解的动作，应与打开的界面或实际结果相符。
2. **让分享与时间状态可信。** 清楚表达谁能看见什么、数据何时更新、哪些操作尚未完成。
3. **让常用任务更省力。** 减少重复标题、过大的装饰区域和分散的入口，同时保留品牌表达。

## 覆盖矩阵

| 用户任务 / 界面 | 本轮操作与观察 | 结果 / 边界 |
| --- | --- | --- |
| 引导 | 四页前后切换、跳过、打断动画、减少动态效果、小屏中文最大字号 | 路径通过；中文按钮与部分标题仍有遗漏翻译 |
| 账号 | 编辑资料、保存、退出、本地 Demo 再登录、账号删除失败保留会话 | 通过；真实 Apple 取消路径仅检查源码 |
| 定位与共享 | 首次允许/拒绝、拒绝后进设置、手动城市、提醒延后、全局开关、单人开关 | 路径通过；发现状态文案不准确、深色对比不足、开关位置偏下 |
| 朋友与邀请 | 添加并接受请求、邀请链接关闭/重启、请求深链接重启后接受 | 用户深链接路径通过；启动注入的旧测试入口仍失败 |
| 朋友详情 | 计划入口、共享、收藏状态显示、移除/屏蔽确认与取消 | 路径通过；取消使用系统弹层实际支持的点外部关闭 |
| 同城与相聚 | 展开/收起、分享取消、失效链接、多条相聚机会与冷启动定位 | 路径通过；复现重复到访时长错误 |
| 个人计划 | 创建、日期跨月与取消、选择朋友、保存、复制私有草稿、关闭浏览、重新进入 | 路径通过；复现草稿取消后丢失，分享模式理解成本仍需用户测试 |
| 城市选择 | 搜索 Palm Springs、中文入口、已有旅行城市入口 | 通过；搜索数据服务的真实断网行为未认证 |
| 共同旅行 | 新建两条、重启保留、编辑、完成/撤销完成、成员移除/离开/删除确认 | 收起键盘后的新建/编辑复测通过；保留键盘态可达性建议 |
| 航班 | 查询候选、无结果、未验证保存、编辑删除、自身/他人权限、详情展开 | 通过；无结果后的主动作说明和中文翻译需完善 |
| 地图 | 展开、选择同行者、全路线/单路线、返程、返回 | 通过；仅航线展示，不宣称实际飞机追踪 |
| 偏好与隐私 | 通知预览、两套外观、Widget 三档隐私、屏蔽空页、隐私摘要 | 通过；跟随系统缺项、通知组织和摘要内容需要改进 |
| Widget 组件 | 两种样式、三档尺寸、浅深色、中文、隐藏姓名/全部、空数据、长城市 | 组件宿主检查；实际桌面安装/刷新另需真机检查 |
| 无障碍与边界 | 系统可访问性扫描、小屏、大字号、长姓名、暂停/不可用位置、无朋友、离线状态 | 确认小热区和姓名截断；原始扫描诊断不直接等同独立缺陷 |

## 优先处理：状态与操作含义

### F01 同城人数卡片打开共享设置，点击含义不一致

**修复更新（2026-09-28）：已实现。** 首页移除共享设置大卡片，保留静态城市状态；同城人数集中在可展开的同城朋友卡。共享设置集中到“你”，异常状态按需提供恢复入口。见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/README.md)。以下保留初评依据。

**优先级：高。依据：XCTest 点击确认 + 视觉观察。** 首页右侧突出“1 位朋友也在这里”和箭头，但整张卡片打开城市共享设置。建议同城人数指向同城朋友，共享设置使用明确文字入口；或将人数并入下方相聚模块。

验证任务：不说明界面，要求首次使用者“找到与你同城的朋友”，记录第一次点击。实现依据：[FriendsView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift:392)。

实测证据：[卡片打开共享弹层](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/final/REVIEW-02-city-sharing-destination.png)。

### F02 未保存表单缺少离开保护 — Complete

**状态：Complete（2026-10-10，本地实现与验证，尚未发布新 TestFlight）。** 资料、个人计划、共同旅行、航班表单在真正修改后提供继续编辑/放弃确认；保护下拉与保存中退出。资料和个人计划已在两种系统完成原生回归，旅行/航班及日期取消复测通过。 见 [详细审计与证据](ui-deep-review-20261010/README.md)。以下保留初评依据。

**优先级：高。依据：XCTest 已复现个人计划、旅行和资料编辑的关闭/取消后输入丢失。** 个人计划、共同旅行、航班表单只在保存过程中禁止下滑关闭；编辑资料的关闭按钮直接 dismiss。填写途中下滑或取消没有草稿保留或“放弃修改”确认。

建议：仅在内容发生变化时提供“继续编辑 / 放弃修改”，或自动保存本地草稿；空白未修改表单继续直接退出。

验证：分别填写城市、日期、旅行名、航班号和个人资料，退出后重进；确认保存中也不能被关闭而留下不明状态。

依据：[个人计划](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/TravelPlans/TravelPlansView.swift:243)、[旅行表单](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Trips/TripPlanningSheets.swift:361)、[航班表单](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Trips/TripsView.swift:1594)、[资料关闭](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Profile/ProfileView.swift:1190)。

实测证据：[旅行填写中](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-19-trip-draft-filled.png)、[取消后重新打开](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-20-trip-after-cancel.png)、[个人计划取消后](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/final/REVIEW-18-plan-after-cancel.png)、[资料关闭后](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-26-profile-after-close.png)。

### F03 单个好友的共享说明始终说“可以看到”，没有反映关闭状态

**修复更新（2026-09-28）：已实现并验证开关组合。** 文案现在随全局共享、逐好友共享及城市是否设置而变化；恢复全局共享保留逐好友选择。见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-20260928/README.md)。以下保留初评依据。

**优先级：高。依据：XCTest 已复现全局暂停与单人关闭两种组合。** 好友详情的说明固定为“某某可以看到你最近所在的城市”，即使该好友开关已关闭，或全局共享已暂停，文案也不随有效状态改变。设置本身可以保留偏好，但应显示实际效果。

建议分别表达“正在向此人共享”“未向此人共享”“全局共享已暂停；恢复后按此设置共享”。验证全局开/关与单人开/关四种组合。

依据：[FriendDetailView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendDetailView.swift:48)。

实测证据：[全局暂停但单人开关开启](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/final/REVIEW-04-friend-global-paused.png)、[单人开关已关闭](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/final/REVIEW-05-friend-sharing-off.png)。

### F04 隐私摘要未跟随旅行功能扩展 — Complete

**状态：Complete（2026-09-28）。** 已补全旅行、航班、同城记录和删除后共同旅行数据保留规则，中英文与政策入口均完成验证。见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/README.md)。以下保留初评依据。

**优先级：高。依据：代码确认。** “已存储”只列身份、好友、共享选择、当前城市及更新时间，没有提到已存在的出行计划、共同旅行、航班和同城事件。删除账号提示也没有清楚说明旅行相关数据对同行者的影响。

建议按实际数据规则补齐摘要，区分“不会保存设备位置轨迹”与“用户主动录入的行程、航班路线”。删除提示应与后端真实处置保持一致；本项是产品透明度评审，不作法律合规结论。

依据：[PrivacyDataView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Profile/ProfileView.swift:1036)。

### F05 深色模式定位按钮白字与浅绿背景对比不足 — Complete

**状态：Complete（2026-09-28）。** 定位、请求接受和允许通知按钮已使用主题对应的文字颜色，请求角标同步调整。深色定位配色对比度约 12.98:1，浅深色测试和截图检查通过。见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/README.md)。以下保留初评依据。

**优先级：高。依据：实测截图 + 颜色数值计算。** 首次定位按钮固定白色前景，背景使用随主题变化的 fresh。深色 fresh 为 RGB (0.651, 0.902, 0.467)，按相对亮度公式计算白字对比度约 **1.48:1**；浅色同组合约 5.72:1。

建议使用语义化“强调色上的文字”颜色：深色模式使用深色字。另需核对红色请求角标白字：当前深色红色 token 的白字对比约 2.43:1。

依据：[定位按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Onboarding/OnboardingView.swift:37)、[主题颜色](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/DesignSystem/AppTheme.swift:94)。这些计算针对明确的实色组合，未把半透明玻璃表面当成已测量对比度。

实测证据：[深色定位按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-24-location-setup-dark.png)。同样的白字浅绿问题也可见于[深色好友请求接受按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-37-request-deep-link.png)和允许通知按钮，建议统一检查强调色上的文字颜色。

### F06 朋友首页缺少清晰的同步失败 / 离线状态 — Complete

**状态：Complete（2026-10-10，本地实现与验证，尚未发布新 TestFlight）。** 首页新增缓存/同步失败提示、上次成功同步时间与重试入口；离线修改明确尚待服务器确认，并保护待提交意图免被旧快照覆盖。受控离线UI与仓储测试通过；真实远端断网仍未认证。 见 [详细审计与证据](ui-deep-review-20261010/README.md)。以下保留初评依据。

**优先级：高。依据：受控 offline 状态截图 + 源码；真实网络断开未实测。** AppStore 能记录 offline，朋友页下拉刷新却没有对应的离线提示和“上次成功同步”状态。好友自身更新时间不等于本机成功同步时间；用户无法区分“朋友没有更新”与“我没连上”。

建议保留缓存列表，同时显示轻量状态：“当前离线，显示上次同步的信息”及重试入口。需要在远端测试环境模拟断网，核对提示消退和数据刷新。

依据：[刷新逻辑](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Core/AppStore.swift:193)、[朋友页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift)。

受控状态证据：[offline 且一小时前同步](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-32-offline-state.png)。

### F07 同城历史时长可能跨多次到访累计 — Complete

**状态：Complete（2026-09-28）。** 已按当前活动 session 起算，缺少 session 时不推测持续时间；上次到访单独保留，同日不同到访也不再合并。7 个逻辑用例及中英文 UI 场景通过。见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f04-f05-f07-20260928/README.md)。以下保留初评依据。

**优先级：高。依据：受控重复到访数据已实测复现。** 当前活跃同城时长采用“活动 session 的 enteredAt”和所有同好友、同城市历史事件时间的最小值。若同一好友曾在此城市与你同城，后又离开并再次相遇，早先事件可能被当成本次开始时间。

建议有活动 session 时以其 enteredAt 为准，回退事件也应限制在本次会话。界面同时应避免把“城市级观测”表述成持续见面或实时共同停留。

实测：当前活动 session 的开始时间为 1 小时前，另有 7 天前的同城事件；页面显示了“Together for 7 days”，而不是约 1 小时。依据：[NotificationHistoryView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Events/NotificationHistoryView.swift:46)。

实测证据：[显示 7 天的错误时长](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-33-repeat-stay-duration.png)、[样例条件与控件树](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-33-repeat-stay-duration-tree.txt)。

## 信息架构与日常交互

### F08 个人计划和共同旅行的边界不够清楚 — Complete

**状态：Complete（2026-09-28）。** 按用户选定的 A「清晰分工」统一“我的出行计划 / My travel plans”“共同旅行 / Shared trips”的名称和用途，补齐双向入口、旅行日期复制及来源/独立保存/分享范围说明。10 个不同相关用例均有通过记录，覆盖中英文、小屏、最大字号、保存和取消；城市复制使用已有 Demo 城市，在线城市搜索限制单独记录。见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-f08-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认入口 + 设计判断。** 好友计划、我的计划、行程分布于不同页面，均包含城市和日期。建议使用任务说明：“告诉朋友何时去哪儿”与“和同行者协调航班”，并提供清晰互相导入/跳转；先测试命名和入口，再决定是否合并。

验证：分别完成“发布自己下周去东京”和“组织三个人一起去东京”，观察选错入口的情况。

### F09 “打个招呼”预期像聊天，实际是系统分享 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 分享动作改名为“分享见面邀约”并使用系统分享图标，iOS 26/27 的打开与取消流程已验证。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：分享面板打开/取消测试 + 视觉观察。** 聊天气泡配“打个招呼”，实际调用 ShareLink。建议用“分享邀约”，或保留“发消息约一下”并明确“选择聊天 App”；取消分享不应产生已发送印象。

依据：[FriendTravelPlansView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/TravelPlans/FriendTravelPlansView.swift:133)。

### F10 收到好友请求后，入口没有优先展示待处理请求 — Complete

**状态：Complete（2026-09-29，已随 TestFlight 1.0.6（27）发布）。** 请求区已置顶并在进入时刷新；接受、拒绝后正确移除，全部处理完恢复邀请内容优先。iOS 26/27 XCTest 通过。 见 [第三批修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave3-20260929/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认 + 设计判断。** 首页加好友图标承载红色请求数，点击却先出现自己的用户名、分享邀请、按用户名邀请，待处理请求在其后。建议有请求时让请求区先出现，或从角标直接定位请求区；无请求时继续突出邀请。

验证：从带角标的首页进入，是否第一屏即可理解并处理请求。依据：[AddFriendView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/AddFriendView.swift:129)。

### F11 发出的好友邀请缺少撤回入口 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 已实现本地、API 和数据库的邀请撤回，验证发送方权限、接受/撤回顺序和通知清理。用户随后授权发布，生产迁移及 API 29 已上线，TestFlight 1.0.6（26）已就绪；见 [发布记录](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/releases/1.0.6-26/README.md)。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认功能缺项。** 发出的好友请求仅显示 Pending；旅行邀请则已有 Revoke。建议至少支持撤回误发的好友邀请，并说明撤回后对方的状态。

这属于需要产品/后端支持的改进，不是改一个按钮即可完成。依据：[请求行](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/AddFriendView.swift:306)。

### F12 好友详情把未来计划放在当前城市之前

**优先级：中。依据：代码确认 + 设计判断。** 从“朋友现在在哪”的主页打开详情，未来计划可能先占据首屏，当前城市被推后。建议优先展示当前城市和新鲜度，再列即将去的城市；从计划专用入口进入时可定位到计划区。

依据：[FriendDetailView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendDetailView.swift:41)。

### F13 个人计划有两层分享语义，开关关闭不等于不分享

**优先级：中。依据：代码确认 + 设计判断。** 选择朋友后关闭“在好友计划中显示”，对方仍能看到日期重叠。现有解释文字有说明，但关键含义藏在小字里。

建议改为明确选项：“仅自己 / 仅显示相聚机会 / 向所选朋友显示完整计划”，使可见范围与模式一起可见。保存前摘要应明确谁能看到什么。

依据：[个人计划共享设置](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/TravelPlans/TravelPlansView.swift:172)。

实测证据：[选择朋友并关闭完整计划浏览](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/final/REVIEW-17-plan-match-only.png)。

### F14 取消 Apple 登录也进入失败提示 — Complete

**状态：Complete（2026-09-29，已随 TestFlight 1.0.6（27）发布）。** 用户取消授权时清理等待状态并安静返回，其他错误继续提示。已验证取消、真实失败与不同错误域；没有操作真实 Apple 账户。 见 [第三批修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave3-20260929/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认，待取消流程验证。** Apple 授权 completion 的 failure 分支没有单独过滤用户取消，而是统一展示登录失败和系统错误文本。

建议用户主动取消时安静返回登录页；真正失败才给出可理解的原因和重试。依据：[AuthenticationView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Auth/AuthenticationView.swift:131)。

### F15 不同日期弹层的取消语义不一致 — Complete

**状态：Complete（2026-10-10，本地实现与验证，尚未发布新 TestFlight）。** 航班日期采用独立选择草稿，取消或下滑不应用修改，只有明确确认才提交；原生取消流程与旅行回归通过。 见 [详细审计与证据](ui-deep-review-20261010/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认。** 个人计划和旅行日期采用局部选择，确认后提交、取消保留原值；航班日期直接绑定父表单 date，点击某天即改值，只有 Done。下滑关闭可能仍保留改动。

建议统一为暂存选择 + “取消 / 确定”，或在界面明确表达即选即生效。验证点选日期后下滑关闭，再次打开表单检查结果。

依据：[航班日期弹层](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Trips/TripsView.swift:1598)。

### F16 通知设置缺少统一的类别总览 — Complete

**状态：Complete（2026-09-29，已随 TestFlight 1.0.6（27）发布）。** 新增五类通知入口、逐人同城设置与逐旅行设置入口；共享旅行状态，明确系统权限和已保存偏好的区别。中英文、开关保存及小屏最大辅助字号检查通过。 见 [第三批修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave3-20260929/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认 + 设计判断。** 总通知页主要提供系统授权和内容预览，同城提醒在朋友详情，航班与行程提醒在每个 Trip。用户想“关闭旅行提醒但保留好友邀请”时，需要先理解分散结构。

建议通知页增加类别及当前有效状态，并链接到具体范围；Trip 通知页在系统通知被拒绝时显示明确状态和设置入口。无需取消现有逐人、逐行程设置。

## 视觉层级与原生适配

### F17 朋友卡的城市装饰压过身份与关键数据

**优先级：中。依据：截图观察 + 设计判断。** 双列大插画卡有辨识度，但姓名、城市、更新时间在有限空间里靠小字承载；多人同城会出现重复插画。

建议制作更紧凑的候选：姓名/头像作为识别锚点、城市其次、时间明确可读，插画作辅助；用 3 / 12 / 30 位朋友和多人同城数据比较查找任务表现。

依据：[朋友卡](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift:536)。

### F18 同城信息重复，展开模块占用过多首页空间 — Complete

**状态：Complete（2026-10-10，本地实现与验证，尚未发布新 TestFlight）。** 采用用户选择的融入页头方案：移除独立大卡片、装饰插画和重复说明，压缩为头像/姓名摘要与更新时间，展开直接进入朋友行。中英文、大字号和深色模式原生检查通过。 见 [详细审计与证据](ui-deep-review-20261010/README.md)。以下保留初评依据。

**优先级：中。依据：截图观察 + 设计判断。** 同城人数、同城摘要、朋友卡同城标签重复；展开态的插画和留白将普通朋友列表推到更下方。建议首页用紧凑相聚摘要和单一明确行动，完整情绪场景保留在二级展示。

“返回朋友”实际是收起首页卡片，建议直接叫“收起”，避免造成已经离开朋友页的错觉。

### F19 好友计划页重复标题，主要内容出现偏晚 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 移除重复的大标题与副标题，缩小创建入口，中英文首条计划的可见位置已验证。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：低。依据：截图观察。** “好友计划”“朋友接下来去哪”“看看好友接下来去哪儿”重复，再加较大的创建卡片，挤压第一条计划。建议移除重复副标题，对已完成首次发布的用户弱化引导卡。

### F20 触控区域与大字号需补齐原生检查 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 计划操作、航班输入/清除/查询/保存与日期控件已完成热区和辅助字号调整，补充原生审计、实际尺寸断言和截图核对；保留原始诊断。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：高（两个计划操作热区）。依据：系统无障碍审计 + 控件实际尺寸。** 航班查询按钮固定 38pt 高；清除航班号是小图标，没有明确扩大的点击区域。好友计划两个小字操作只给共同父容器设置 44pt，本轮系统测得两个子按钮分别约 109×14.8pt、75.5×14.5pt，均报告“Hit area is too small”。

建议交互热区按 44×44pt 的常用设计目标检查，外观可保持紧凑；航班表单固定横排还需测试最大字号和小屏。日历及大字号不能仅检查“存在”，还应核对完整标签和相邻控件是否误触。

依据：[航班查询](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Trips/TripsView.swift:1390)、[Apple UI 设计建议](https://developer.apple.com/design/tips/)。

实测证据：[无障碍扫描摘要](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/accessibility-summary.json)、[最大字号姓名截断](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-34-long-name-largest-text.png)。系统共返回 93 条原始诊断，其中包括重复、装饰性头像和未定位元素的提示，不能写成 93 个已确认缺陷。

### F21 外观缺少“跟随系统” — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 新增并默认“跟随系统”，保留已有明确浅/深偏好，App/Widget 共用偏好；已验证系统深色及重启持久化。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认功能缺项。** 外观只有 Solar Jade / Night Jade，并在根界面强制指定 color scheme。建议增加“跟随系统”并作为默认；两套品牌主题可以继续保留。

依据：[外观设置](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Profile/ProfileView.swift:375)、[外观枚举](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/DesignSystem/AppTheme.swift:4)。

### F22 部分动态文案仍绕过中文本地化 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 补齐本轮列出的航班、无结果、当天日期、自动旅行名、创建表单、引导/辅助标签、分组和相对时间中文；日期范围按当前语言格式化。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：中英文实测截图 + 源码。** 可定位到航班日期硬编码 Today、无航班结果英文句子，以及自动生成的“城市 trip”旅行名。这些不是用户主动输入的英文内容，应该本地化。朋友列表的 m/h/d 也可统一为适合当前语言的紧凑时间格式。

建议中文测试同时覆盖正常、失败、今天、跨年和自动命名；不要只看正常结果截图。

依据：[航班日期和无结果](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Trips/TripsView.swift:1221)、[自动旅行名](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Trips/TripPlanningSheets.swift:133)。

实测补充：遗漏还包括航班弹层的 Add flight / Search / Add my flight / Select Departure Date，以及中文引导的 Skip / Get started 和部分分组标题。[航班表单](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-21-flight-keyboard-small.png)、[中文引导最后一页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-36-onboarding-AX-3.png)。

## 新鲜度、Widget 与长期使用

### F23 新鲜度与“此刻同城”的确定性不完全匹配

**优先级：中。依据：代码确认阈值 + 设计判断。** 同城匹配接受双方 24 小时内的位置；卡片却使用“此刻同城”这种很即时的措辞。朋友位置要到 14 天才进入 stale 并出现“太旧，不参与同城提醒”的解释，而实际同城资格在 24 小时后已失效。

建议保留低功耗策略，用更准确的“最近同城”或明确显示双方更新时间；在不能参与匹配时解释原因。是否缩短阈值属于产品决策，应结合更新可靠性评估。

依据：[新鲜度分级](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/Models/FriendPresence.swift:85)、[同城策略](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/Models/AppDomain.swift:533)。

### F24 Widget 点击朋友后统一打开首页 — Complete

**状态：Complete（2026-09-29，已随 TestFlight 1.0.6（27）发布）。** 小尺寸直达好友，中大尺寸逐行链接；隐私隐藏模式保留通用入口。URL 与隐私单测、App 冷启动与失效目标检查通过；真机桌面 Widget 点击未认证。 见 [第三批修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave3-20260929/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认。** Home Screen 好友 Widget 的内容整体包在指向 home 的 Link 中。用户点击某位朋友仍需在 App 内再找一次。

建议小尺寸跳对应朋友；中、大尺寸在平台支持的范围内提供行级深链接。隐私隐藏模式可保留通用首页入口，避免在链接行为上暴露被隐藏的身份。

依据：[FriendDirectoryWidget](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/Components/HomeWidgetViews.swift:85)。

### F25 部分 Widget 为“同城”让出了更新时间

**优先级：中。依据：代码确认 + 已有 Widget 视觉观察。** 小尺寸在同城时用“与你同城”替代更新时间；大尺寸同城行用 Here too 替代时间；中尺寸紧凑行也没有时间。由此无法仅靠这些 Widget 判断城市数据的新鲜程度。

建议紧凑组合“同城 · 8 分钟前”，或提供清晰的最后更新时间。锁屏尺寸限制应单独权衡，不把所有尺寸强行套成同一版式。

依据：[Widget 小尺寸](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/Components/HomeWidgetViews.swift:101)、[Widget 行](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Shared/Components/HomeWidgetViews.swift:165)。

### F26 同城历史缺少时间更新与长文本适配 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 保留每分钟和前台更新时间，补齐长姓名、城市和参与者换行；已用真实等待和最大字号验证。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：代码确认，需运行时核查。** 页面 referenceDate 在初始化后没有定时更新，停留页面时“已同城多久”可能保持原值；朋友姓名和城市多处强制一行，对长姓名及大字号不友好。

建议活跃状态定时更新，回到前台立即刷新；大字号允许换行。历史静态卡不用无意义地持续重排。

依据：[NotificationHistoryView](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Events/NotificationHistoryView.swift:5)。

### F27 航班未查到结果时，主按钮没有解释保存结果 — Complete

**状态：Complete（2026-10-10，本地实现与验证，尚未发布新 TestFlight）。** 无查询结果时明确使用“保存航班号”，解释航线与时间尚未验证；说明位于可滚动区域。已验证、未验证、未知号码及大字号流程通过。 见 [详细审计与证据](ui-deep-review-20261010/README.md)。以下保留初评依据。

**优先级：中。依据：XCTest 实际截图 + 实现确认。** 中文航班查询无结果后，仍显示同样的 “Add my flight” 主按钮。用户可以保存，但保存的是未验证航班，时间、路线等信息可能缺失。现有功能支持这种回退是有价值的，应在提交前解释，而不是等保存后才看到未验证状态。

建议无候选时将按钮改为“先保存航班号”，并说明“暂未验证，航线和时间尚未获取”；有选中候选时使用“添加此航班”。不要将查不到结果等同于航班不存在。

证据：[查询无结果与主按钮](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-22-flight-no-result-chinese.png)。

### F28 旅行表单的键盘状态增加了继续操作的成本 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 保存操作固定在键盘上方安全区域，并提供完成按钮；两种屏幕上的键盘态保存、编辑均已验证。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：中。依据：初始测试失败，收起键盘后对照复测通过。** iPhone 18 Pro 的新建/编辑测试在输入旅行名后继续选择目的地或保存时失败，页面仍停留在表单和键盘。小屏截图也显示名称输入占据可见底部，保存按钮需要额外滚动或收起键盘才能找到。

建议对齐航班表单的做法，把保存动作固定在键盘上方的安全区域；输入完成提供明显的“完成”。在原失败设备上，增加键盘“完成”操作后，新建两条旅行、重启保留、编辑、完成和撤销均通过。因此保留为键盘态可达性改进，撤回“无法创建或编辑”的推断；是否涉及真实触摸丢失还需真机复核。

证据：[输入旅行名时的小屏布局](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/small/REVIEW-19-trip-draft-filled.png)。

### F29 城市共享弹层把关键共享开关放得太靠下 — Complete

**状态：Complete（2026-10-10，本地实现与验证，尚未发布新 TestFlight）。** 共享我的城市与有效状态移至弹层顶部，城市装饰信息随后，辅助字号使用完整高度。小屏中文最大字号与实际共享暂停/恢复流程通过。 见 [详细审计与证据](ui-deep-review-20261010/README.md)。以下保留初评依据。

**优先级：中。依据：小屏实际截图。** 默认高度的共享弹层先显示城市插画、城市长名、更新时间、刷新和手动城市按钮，“共享我的城市”开关在首屏底部被截断，后台更新更靠下。对于想立即暂停共享的人，设置入口到了，关键控制还要继续找。

建议把共享开关与有效状态放在弹层顶部；城市展示缩为次级信息，或小屏默认打开完整高度。不要让隐私控制的位置取决于城市名字是否换行。

证据：[共享弹层初始状态](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-02-city-sharing-destination.png)。

### F30 没有好友时，首个邀请动作不够突出 — Complete

**状态：Complete（2026-09-28，本地实现与验证）。** 空首页突出直接分享“邀请第一位朋友”，保留用户名入口，隐藏空好友计划分支；取消分享与后续用户名入口均已验证。 见 [修复记录与截图](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)。以下保留初评依据。

**优先级：低。依据：空数据样例截图 + 设计判断。** 空首页仍有朋友数、城市数、同城人数和好友计划入口，真正的“添加朋友”是大空白卡片中的小按钮。建议空状态以“邀请第一位朋友”为明确主动作，弱化零值统计和暂时没有内容的分支。

邀请页已有分享链接，建议将此能力直接接到首次使用的主动作，同时保留按用户名添加。虚构 Demo 的说明文案不当作生产文案缺陷。

证据：[没有朋友的首页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-ux-review-20260928/evidence/followup/REVIEW-30-empty-friends.png)。

## 应保留的实现与表现

- 城市级分享与精确定位追踪的边界较清楚；手动城市有独立入口。
- 个人计划默认可以保持私有，复制朋友计划先打开可检查的草稿。
- 旅行有完成与撤销完成，永久删除也有明确的范围说明。
- 航班未验证状态没有伪装成真实查询结果，保存失败文案承诺保留输入。
- 多处已有异步禁用、失败重试、加载状态和深链接失效处理。
- 主题、城市插画与新版 Widget 已有品牌基础，无需全量推翻。

## 仍需专门验证的外部和长期行为

本轮评审结束后，下面这些项目保留为明确的验证边界，不把本地样例通过外推成线上保证：

- 真实 Apple 登录的取消/失败体验、真实账号删除后的云端数据处置。
- 两个真实账号间的邀请、通知、并发修改、拒绝权限后的 APNs 送达；本轮请求链接使用虚构数据。
- 真实断网、恢复网络、后台定位周期与电量；offline 只做 UI 状态注入。
- 桌面与锁屏 Widget 的安装、编辑、系统刷新时机和实际点击；本轮组件渲染与隐私状态已测，入口行为核对源码。
- 真机 VoiceOver 连续导航、长时间停留后的计时更新，以及真实用户能否理解术语和分享范围。

这些边界不妨碍修正已复现的小热区、低对比度、分享文案、同城时长和本地化问题。

## 依据与交付物

- 对照用历史 App 截图：[原始截图目录](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/app_store_screenshots/2026-09-25/raw/zh-Hans)
- 对照用历史 Widget 截图：[浅深色预览](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/widget_redesign/2026-09-26/review-overview.png)
- 本轮构建记录：[App 构建日志](/private/tmp/across-us-ui-review-build.log)、[测试编译日志](/private/tmp/across-us-ui-review-test-build.log)
- 方法依据：[Apple 无障碍设计](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[Apple 数据输入](https://developer.apple.com/design/human-interface-guidelines/entering-data)、[Apple 引导设计](https://developer.apple.com/design/human-interface-guidelines/onboarding)、[NN/g 可用性原则](https://www.nngroup.com/articles/ten-usability-heuristics/)。

F01、F03、F04、F05、F07、F08、F09、F11、F19、F20、F21、F22、F26、F28、F30 已完成本地修复。后续建议优先处理 F02 与 F06，再处理入口、分享和通知理解，之后做视觉层级和 Widget 精修。视觉建议均需对照图和任务验证，不以主观分数代替证据。
