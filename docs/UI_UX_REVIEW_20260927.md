# Across Us：设计 skills 筛选与首轮 UI/UX 评审

后续已完成 XCTest 与逐屏评审，请以 [完整评审报告](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/UI_UX_FULL_REVIEW_20260927.md) 为准。本文保留最初的技能筛选和初评记录。

评审日期：2026-09-27（美国西海岸）。

结论：保留奶油色底、深绿色文字和城市立体插画。当前更值得投入的是首页的信息主次、按钮含义与实际行为的一致性，以及“个人计划 / 共同旅行”的理解成本。先处理这些，再做局部视觉精修。

## 范围与证据

这是一轮基于真实截图和当前代码的静态专家评审，由本次会话直接完成；没有运行或安装下方推荐的第三方 skills，也没有另起评审代理。它不等于真人可用性测试或完整的真机交互验收。

查看了仓库留存的五张中文原始模拟器截图：朋友首页、好友计划、即将相聚、此刻同城、行程列表。截图来自 2026-09-25 目录，目录说明记载制作完成于 9 月 26 日。用当前 FriendsView、AppShellView、FriendTravelPlansView、SharingView、AppTheme 等代码核对相关结构和行为。没有将商店宣传海报当作 App 界面。

- [朋友首页](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/app_store_screenshots/2026-09-25/raw/zh-Hans/01-friends.png)
- [好友计划](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/app_store_screenshots/2026-09-25/raw/zh-Hans/02-friend-plans.png)
- [即将相聚](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/app_store_screenshots/2026-09-25/raw/zh-Hans/03-together-soon.png)
- [此刻同城](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/app_store_screenshots/2026-09-25/raw/zh-Hans/04-here-together.png)
- [行程列表](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/app_store_screenshots/2026-09-25/raw/zh-Hans/05-shared-trips.png)

未实测：当前构建的动效、真实点击热区、VoiceOver、最大字号、小屏、深色模式、首次注册与权限全流程、网络异常。下文把可确认的实现事实与用户反应假设分开说明。

## 最适合这次任务的 skills

安装量与星数是查询时页面显示的约数，仅用于判断采用情况，不代表审美水平或评审准确率。

| Skill / 来源 | 页面显示安装量 / 仓库星数 | 对 Across Us 的用途 | 使用边界 |
| --- | --- | --- | --- |
| [Impeccable](https://www.skills.sh/pbakaus/impeccable/impeccable)，pbakaus/impeccable | 298K / 71.8K | 首选；critique 审视层级、清晰度和体验，polish 做后续精修 | 浏览器与 DOM 自动检测不能代替原生 iOS 实测；设计意见需结合原生规范 |
| [UI UX Pro Max](https://www.skills.sh/nextlevelbuilder/ui-ux-pro-max-skill/ui-ux-pro-max)，nextlevelbuilder | 373.4K / 131K | 配色、字体、间距、交互规则的备查库，含 SwiftUI 指导 | 给既有品牌做局部校正；避免每个页面生成一套新风格 |
| [SwiftUI Expert](https://www.skills.sh/avdlee/swiftui-agent-skill/swiftui-expert-skill)，AvdLee | 33.1K / 3.6K | 把评审意见落到 SwiftUI 状态、布局、导航、可访问性和性能 | 主要是原生实现质量，不应当作审美裁判 |

维护者资料核对：[Impeccable 命令说明](https://github.com/pbakaus/impeccable)、[UI UX Pro Max 支持平台](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)、[SwiftUI Expert 仓库](https://github.com/AvdLee/SwiftUI-Agent-Skill)。Impeccable 当前采用统一的 `/impeccable critique`、`/impeccable audit` 等命令；搜索结果仍能看到旧的独立 critique/audit 条目。

安装命令供后续选择使用，本轮未执行：

```sh
npx skills add https://github.com/pbakaus/impeccable --skill impeccable
npx skills add https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max
npx skills add https://github.com/avdlee/swiftui-agent-skill --skill swiftui-expert-skill
```

最小组合建议：Impeccable 负责审美与体验批评，SwiftUI Expert 负责原生实现核查。需要制定或调整视觉规范时再引入 UI UX Pro Max。

## 首轮发现

### 1. 高优先级：同城人数卡片的视觉含义与点击去向不一致

**事实：** 首页“你的城市”卡片右侧突出“1 位朋友也在这里”和右箭头，但整张卡片绑定 `onOpenCitySharing`，打开的是城市共享设置。

**推断：** 以寻找同城朋友为目的的用户，可能预期箭头带他查看那位朋友。实际进入设置会产生跳转错误的感觉。用户是否确实误解，需要任务测试确认。

**建议：** 将同城人数明确指向同城朋友；为共享设置提供带“共享设置”文字的独立入口。也可将当前卡片改成纯粹的共享状态卡，把人数整合进下方同城模块。

**验证：** 不解释界面，让首次使用者完成“查看谁和你在同一座城市”，记录首次点击位置。

代码：[卡片点击行为](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift:392)、[共享设置入口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/App/AppShellView.swift:36)。

### 2. 中优先级：“打个招呼”没有说明会打开外部分享

**事实：** 好友计划卡的“打个招呼”使用聊天气泡图标；代码是 `ShareLink(item: greeting(for: plan))`，交给系统分享面板，不直接向这位朋友发送消息。

**推断：** 用户可能以为进入一对一聊天，甚至误以为点一下就能通知对方。当前静态证据能确认实现，不能证明误解发生率。

**建议：** 保留温暖语气，但明确下一步，例如“发消息约一下”，辅以“选择聊天 App”；或用“分享邀约”及分享图标。不得显示“已发送给朋友”，除非有真实发送结果。

**验证：** 点击前询问用户“你觉得接下来会发生什么”；取消分享后核对页面是否仍准确表达未发送状态。

代码：[ShareLink](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/TravelPlans/FriendTravelPlansView.swift:130)。

### 3. 中优先级：“好友计划 / 我的计划 / 行程”的区别需要用户自行推断

**事实：** “好友计划”位于朋友页的小型入口，“我的计划”可从其右上角或个人页进入，“行程”则是独立底部标签。截图中这些功能均围绕未来城市、日期和旅行。

**推断：** 想发布“我下周去东京”的用户，可能先进入“行程”，但那里主要组织共同旅行与航班。信息架构体现了功能边界，尚未充分解释用户任务的边界。

**建议：** 先用文案和互相链接降低成本，例如“我的出行计划：告诉朋友何时去哪儿”与“共同旅行：协调同行者和航班”。是否合并入口，需要先验证，不能仅因名字接近就合并数据模型。

**验证：** 分别测试“告诉朋友我的旅行日期”和“和两位朋友一起安排旅行”，观察是否能选对入口。

证据：好友计划和行程列表截图；[主导航](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/App/AppShellView.swift:46)、[好友计划入口](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift:301)。

### 4. 中优先级：城市插画形成品牌记忆，但在朋友列表中压过了人的身份

**观察：** 首页是大尺寸城市插画的双列卡片，姓名在插画下方，城市和更新时间更小。当前代码为插画分配 88pt，城市使用 caption，更新时间使用 caption2。多位朋友在同城时，城市图形会重复。

**设计判断：** 这套插画值得保留；在以找人为主的列表里，应提高“谁”的辨识度，让插画承担地点和情绪表达。具体效果需对照稿验证。

**建议：** 先制作一张更紧凑的朋友卡作为候选：增加头像或姓名首字母的身份锚点，保持姓名最先被读到，再是城市和更新时间，城市插画缩为辅助。特别比较 3 人、12 人、30 人，以及多人同城的情形。

**验证：** 给出指定朋友姓名，观察找到其城市的时间与错误；再单独比较用户对品牌风格的偏好，不把两种结果混成一个主观分数。

代码：[朋友卡的视觉层级](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/Friends/FriendsView.swift:543)。

### 5. 中优先级：同城信息重复呈现，展开态占用较多首页空间

**观察：** “1 位朋友也在这里”、下方“此刻同城 · Mia Chen”、朋友卡上的“同城”重复传达同一事件。同城和即将相聚的展开态含大面积插画与留白，挤压下方朋友列表。截图能确认空间分配，但不能据此认定动画或滚动存在故障。

**建议：** 首页优先显示紧凑、可直接行动的相聚摘要：“Mia 和你都在纽约 · 更新于 8 分钟前”，配一个明确动作；丰富的插画和庆祝场景放到详情或用户主动展开后的第二层。先调整单个模块，不同时重做整个首页。

**验证：** 用户是否既能快速发现相聚机会，也能继续浏览其他朋友；“收起”和“返回朋友”的含义是否一致可理解。

证据：朋友首页、此刻同城、即将相聚三张截图。

### 6. 低优先级：好友计划页存在重复标题和偏重的引导区域

**观察：** 导航标题“好友计划”、大标题“朋友接下来去哪”、副标题“看看好友接下来去哪儿。”表达高度接近；后面还有“添加我的计划”大卡片。真正的好友计划要在这些内容之后出现。

**建议：** 删除重复副标题。已有个人计划的用户可以看到更轻量的添加入口；首次使用者保留完整引导。让第一条好友计划更早出现。

**验证：** 首次进入和重复访问分别查看，确认首次使用仍知道如何发布自己的计划，老用户能更快读到好友内容。

证据：好友计划截图；[页面结构](/Users/wangyang/.gemini/antigravity/where_is_my_friend/WhereIsMyFriend/Features/TravelPlans/FriendTravelPlansView.swift:20)。

## 应保留的设计

- 奶油底色、森林绿文字与城市立体插画形成较一致的品牌风格。
- 相聚场景围绕“人和见面”，有温度，适合城市级分享产品。
- 首页包含更新时间和同城文字，具备表达位置新鲜度的基础。
- 当前实现对部分大字号布局、空状态和失败重试已有处理，应延续这些基础。

## 下一轮实际交互验证

这些是待验证事项，不是本轮已确认缺陷：

| 场景 | 需要回答的问题 |
| --- | --- |
| 首次使用、没有好友 | 能否理解城市级分享并完成第一位好友邀请？ |
| 查找同城朋友 | 第一次点击是否到达预期页面？ |
| 发布自己的计划 | 能否区分个人计划和共同旅行？ |
| 暂停共享、手动设置城市、拒绝定位 | 用户是否清楚朋友能看到什么，以及如何恢复？ |
| 过期位置、离线、请求失败 | 是否把“上次所在城市”误读成实时位置？能否恢复操作？ |
| 小屏、长姓名、长城市名、最大字号 | 姓名、城市、日期、隐私状态是否被截断？ |
| 深色、降低透明度、减少动态效果、VoiceOver | 关键内容和操作是否保持可用？ |
| 好友计划卡下方两个操作 | 父容器设为 44pt 不足以证明每个子控件的实际热区；需逐一实测 |

评审基准可参考 [Apple 无障碍设计指南](https://developer.apple.com/design/human-interface-guidelines/accessibility) 和 [NN/g 十条可用性原则](https://www.nngroup.com/articles/ten-usability-heuristics/)，重点检查状态可见性、用户控制、术语一致和识别成本。它们帮助解释问题，不代替实际用户观察。

## 可直接采用的小技巧

1. **点击前预测：** 遮住下一屏，让未参与开发的人说出按钮会做什么，再实际点击。特别适合本轮第 1、2 项。
2. **五秒首屏：** 看五秒后移开界面，问“谁和你同城、数据多新、下一步能做什么”。这是一种快速诊断，不是统计结论。
3. **一次只改一个主问题：** 先做同城卡或朋友卡的前后对照，用相同数据、屏幕尺寸和语言比较。
4. **状态成组看：** 同一界面同时准备无数据、正常、加载、失败、暂停、数据过期版本，避免只打磨演示数据最漂亮的一屏。
5. **把意见写成可验证的任务：** 用“用户在某场景看到什么、可能误解什么、最小改法是什么、如何判断改好了”替代“更高级一点”。

## 建议执行顺序

先核查并解决第 1、2 项动作预期，再用任务测试决定第 3 项入口与命名；之后对朋友卡和同城模块做局部对照设计；最后完成原生状态与可访问性验证。

仓库现有设计规范的主导航仍写着 Friends / Sharing / You，而当前代码已是 Friends / Trips / You。正式改版前应同步规范，以当前产品目标和实际实现为评审基础，避免把旧规范当成唯一正确答案。

本轮只新增这份报告，没有修改 App 源代码。
