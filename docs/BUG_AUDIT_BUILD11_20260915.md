# Across Us 1.0.2 (11) — 异常路径审计

## 范围与证据

- 基于刚上传的 build 11。当前工作区中的发布输入与 `/private/tmp/across-friend-plans-release-20260915.a5vum4es/source-manifest.json` 一致；本轮未修改应用实现、部署后端或上传新版本。
- 客户端诊断在 `/private/tmp/across-build11-bug-audit-nxz6op9a/source` 的独立副本中运行，使用原版 AppStore、RemoteAppRepository、OfflineMutationQueue 和模型。仅添加诊断测试与假 Repository 的网络延迟，不访问真实账号。
- 数据库诊断使用内存 PGlite，加载 build 11 对应迁移及合成 Alice/Bob 数据，跳过未在线上部署的旧 `20260901220000` 迁移。没有对生产数据执行写入，也没有发送 APNs。
- 诊断测试中的断言用于确认不正确行为确实出现；“诊断通过”不代表这些 bug 已修复。
- 现有发布测试已覆盖正常流程，但没有覆盖下面这些时序和输入组合。本轮不重复把过去的全部测试通过当作异常路径已安全的证明。

## F1 · P1 · 旧离线操作会覆盖后来成功保存的“关闭城市共享”

**位置：** `Core/RemoteAppRepository.swift:351`、`:567`，`Core/ClientReliability.swift:195`。

**已复现的过程：**

1. 离线时开启城市共享，旧的 `citySharingEnabled=true` 写入重试队列。
2. 联网后，用户关闭城市共享；新请求成功，服务器响应为 false。
3. 旧操作没有随这个成功请求失效，队列仍剩 1 条。
4. 后续同步重试旧操作，又向服务器发送 true。

诊断输出：`saved_pause=true, queued_after_success=1, replayed_writes=[false, true], final_sharing=true`。

**根因：** 队列仅在新操作也失败并入队时合并；直接成功的更新不会淘汰同一设置的旧队列项。重试端也没有版本判断，原样发送旧的整份设置。

**影响：** 用户确认关闭的共享会被恢复。这不是“离线关闭尚未送达”的正常延迟，而是一个已成功的新选择被旧操作覆盖。

**建议：** 为设置操作建立统一顺序和版本。在线与离线走同一个提交路径，旧任务不能覆盖较新的已确认选择；清理队列时不能误删正在产生的新任务，仅删掉自身或已被取代的版本。

**验收：** 离线开启 → 在线关闭 → 重试后仍关闭；反向组合也遵循最后一次用户选择；覆盖重试与新写入同时进行的情况。

## F2 · P1 · 连续操作两个开关，可能把刚关闭的共享恢复

**位置：** `Features/Sharing/SharingView.swift:202–233`、`Core/AppStore.swift:336`。

**已隔离复现：** 按界面绑定中的相同逻辑，先提交关闭城市共享；在响应返回前改变 Background updates。两个绑定都从旧的 `store.snapshot.sharingPreferences` 复制整份设置，第二次请求仍带着 `citySharingEnabled=true`。

在假后端增加 120 毫秒延迟、两次操作相隔 20 毫秒时，两次保存都报告成功，最终共享为 true。输出：`first_city_sharing=false, second_city_sharing=true, final_city_sharing=true`。

**边界：** 使用真实 AppStore、界面中相同的取值/修改方式和模拟延迟复现；本轮没有用真机自动点击来测发生率。

**根因：** 本地的 `pendingSharingEnabled` 只影响显示，没有合并进另一个开关的提交；两个开关也没有共享的待保存状态或串行化策略。AppStore 的“只采纳最新响应”防护无法修正第二个请求本身已经携带旧值的问题。

**建议：** 使用一个共同的待保存设置模型，或提交只包含发生变化字段的更新，并按顺序确认。短期也可以在当前设置提交完成前禁用相关开关。

**验收：** 关闭共享与开启/关闭后台更新快速交替时，共享最终保持用户最后选择的状态；响应乱序也不能覆盖另一个字段的新选择。

## F3 · P1 · 旧账号定位请求迟到失败，会被归入新账号队列

**位置：** `Core/RemoteAppRepository.swift:367–399`，特别是 `:388`。共享设置的 `:355` 和设备注册的异常分支也有相同的“失败时才读取当前账号”模式；本轮针对定位路径完成复现。

**已隔离复现：**

1. A 的定位请求带着 A 的假 token 发出，城市为 Tokyo。
2. 请求尚未结束时，注入一个已完成的新登录状态：当前账号为 B，B 原城市为 Paris，认证对象返回 B 的 token。
3. A 的旧请求返回超时。异常处理此时才调用 `activeUserID()`，得到 B，因此把 A 的 Tokyo 上传写入 B 的队列。
4. 触发重试，实际发出的请求使用 B 的 token，正文城市仍为 Tokyo。

诊断输出：`old_owner_queue=0, new_owner_queue=1, replay_bearer=Bearer token-b, replay_city=Tokyo`。这里的 token 是测试替身，不是真实凭据。

**影响与边界：** 这确认了网络/账号切换边界上的错误归属，可以让旧位置写入新账号。本轮没有用真实 Apple ID 切换账号或测量触发频率，也不是陌生人可以绕过鉴权读取账号的证据。AppStore 丢弃旧响应只能保护画面，不能撤销 Repository 已经错误归属的队列项。

**建议：** 请求开始时固定账号 ID 和登录代次，失败入队、token 刷新重试和本地快照回退都验证同一身份。账号已经变化时，旧请求不得读取新账号缓存或借用新账号身份提交数据。

**验收：** A 发起请求 → 注销/切到 B → A 请求失败时，不产生 B 的队列项，不用 B 的凭据重放；对定位、共享设置、设备注册及身份刷新重试分别覆盖。

## F4 · P2 · 同一城市的行政区缩写不同，会漏掉未来重叠

**位置：** `supabase/migrations/20260915040000_friend_travel_plans.sql:83–85`，`Core/TravelPlans.swift:9`。

**已复现：** 两个已互为好友、互相共享计划的用户，在相同日期、相同时区前往 New York / US，其中一个 region 为 `NY`，另一个为 `New York`。

- 当前城市身份函数认定两者相同：`currentPresenceKeysMatch=true`。
- 未来计划生成两个不同的 key：`US:newyork:ny:America/New_York` 与 `US:newyork:new york:America/New_York`。
- `futureOverlapCount=0`；把第二份计划行政区改成 `NY` 后，重叠数变为 1。

**边界：** 两种合法 API 输入下的 SQL 漏匹配已经确认；不同设备/语言下地理编码实际返回这些别名的频率尚未测量。不能由此断言所有纽约用户都会漏匹配。

**建议：** 未来计划也使用规范化后的行政区身份，前端、数据库和通知统一。调整旧 key 时处理通知去重，避免把迁移当作新重叠再次推送。

## F5 · P2 · 未来重叠提醒的第五次发送，可能被另一个任务提前作废

**位置：** `supabase/migrations/20260911010000_personal_travel_plans.sql:155–159`、`supabase/functions/_shared/travel-plans.mjs:38`。

**已复现：** 一条提醒被领取进行第五次尝试，其发送凭据仍有效。此时另一个任务调用 `wif_travel_claim`，清理逻辑只看到 `attempts>=5`，就将它标为 failed，并清空发送凭据；没有检查原来的两分钟处理窗口是否仍有效。

输出：`preparedBefore=true, preparedAfter=false, status=failed, attempts=5, token_cleared=true, lease_cleared=true`。

**实际触发条件：** 慢网、后端延迟或积压导致两个定时任务重叠。未来提醒按条顺序发送，一批最多 10 条，任务执行时间可能跨过下一次调度。本轮复现的是数据库任务竞争，没有模拟或发送真实 APNs，也没有声称线上已经出现漏通知。

**影响：** 最后一次有效尝试可能还没发送就被跳过；如果 APNs 请求已经发出，其完成结果也可能无法回写。

**建议：** 超出尝试次数的清理只处理没有有效领取者或领取已过期的条目，保持与新好友邀请队列的处理原则一致。权限撤回仍应立即使发送失效。

## 次要显示问题 · P3

个人计划和重叠卡片的日期只附带结束年份。`2026-12-29 → 2027-01-03` 显示为 `Dec 29 – Jan 3, 2027`，省略起始年份。已由真实模型确认，不影响实际保存或匹配日期。建议复用 Trips 已有的跨年格式，跨年时两端都显示年份。

位置：`Core/TravelPlans.swift:32`、`TravelOverlap.dateLabel`；好友计划详情复用了同一日期标签。

## 上一轮已指出、build 11 仍未修复

- **个人计划／Trips 的旧账号磁盘缓存清理不完整。** 账号断开时清的是内存和主 App/Widget 快照，两个新模块的独立磁盘缓存仍存在；这不等于另一账号可以直接读取，也不等于服务器删号失败。
- **手动当前城市入口缺失。** 定位拒绝时仍提示“可以手动选择”，但正式界面只有刷新定位与系统设置入口。未来计划选城不等于设置当前城市。

这两项不作为本轮新发现重复计数；此前证据见 `PRODUCT_AUDIT_AND_ROADMAP_20260915.md`。

## 建议顺序

1. 优先修复共享设置的顺序与队列淘汰问题（F1/F2），保留有针对性的回归测试。
2. 一并修复账号切换后的请求身份隔离（F3）。
3. 修复行政区身份规范化与通知重试竞争（F4/F5）。
4. 合并缓存清理、手动选城和跨年显示修正，再进行真机弱网、切后台、账号生命周期与通知测试。

## 诊断文件

- 代码基线与隔离副本：`/private/tmp/across-build11-bug-audit-nxz6op9a/`。
- 首轮客户端诊断：`repro-verified.xcresult`、`repro-verified.log`。3 个诊断用例确认了 F1、F2 和跨年显示行为。
- 数据库诊断：`sql-repro.mjs`、`sql-results.json`，确认了 F4/F5。
- 账号隔离诊断：`account-repro.xcresult`、`account-repro.log`，额外 1 个诊断用例确认 F3。
- 本轮共完成 4 个客户端诊断用例和 2 组 SQL 诊断。初次搭建测试副本时漏复制城市 JSON 资源，补齐后编译并执行成功；该搭建错误不列为 App bug。
