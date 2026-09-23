# Across Us 项目审计 — 2026-09-15

## 范围与结论

本轮检查当前本地工作区、数据库迁移与客户端/后端测试，不修改实现、不部署、不上传版本。所有“已复现”均指本地隔离环境，不代表已查看线上用户日志。

项目已具备真实账号、好友关系、城市分享、个人未来行程、跨设备 Trips、本人航班维护、邀请与可选推送的主要链路。近期定位和城市群工作属于本地待发布改动；城市群目前只复用图标，未扩大地理匹配/通知范围，也未导入全球都市区数据。

主要风险已从“缺少页面”转向跨层规则不一致、异常路径和发布环境区分。建议下一版本以稳定性为主，而不是继续扩展功能。

## 验证结果

- 重新运行：98 项客户端单元测试通过，0 失败。结果 `/private/tmp/wif-audit-unit-20260915.xcresult`。
- 重新运行：68 项后端测试通过，0 失败。日志 `/private/tmp/wif-audit-backend-20260915.log`。
- 额外 SQL 诊断使用全量迁移、合成的 Alice/Bob 和内存 PGlite 数据库，未触及 Supabase：`/private/tmp/wif-audit-repro-20260915.mjs`。
- 额外定位诊断从当前 `PlatformServices.swift` 提取 CityLocationService 原实现，注入假定位管理器/地理编码器，并将 20 秒超时缩短为 150 毫秒，在专用 iOS 模拟器运行：`/private/tmp/wif-location-audit-20260915.swift`。
- 本轮没有运行完整 UI 测试、真实 Apple ID 登录、真实 APNs 收件、跨城真机后台测试，也没有核实 App Store 当前已上架 build 或线上 Edge Function 版本。不能用本地测试通过证明这些链路已在线上修复。

## F1 · P1 · 同国、不同州的同名城市仍会被判定为同城（已复现）

位置：`WhereIsMyFriend/Shared/Models/AppDomain.swift:531`、`supabase/migrations/20260915010000_city_region_metadata.sql:283`。

州信息已被保存，且图标归属使用州信息，但真正的 CityIdentity key/matches 和 `wif_city_key` 仍只有城市名与国家。新增行政区字段没有进入同城身份。

复现：两个已互为好友的测试账号分别更新 Pasadena / US / CA 和 Pasadena / US / TX。数据库为两人各生成了一条 Pasadena 同城事件，共 2 条。它们并不在同一个城市，也不是本次认可的城市群合并。

建议：以城市的稳定 ID，或至少国家 + 行政区 + 规范城市名匹配；对缺少州信息的历史记录使用明确的保守兼容规则。前端、SQL 和通知必须同时调整，不能仅修图标。升级 key 时不得把数据迁移当成新到达批量推送。

验收：CA/TX Pasadena 不匹配；CA/UT Santa Clara 不匹配；同州同城匹配；历史缺失行政区的数据不被猜测归类。

## F2 · P1 · 同城时效规则分裂，旧迁移没有接入实际调用链（已复现）

位置：`docs/retired-migrations/20260901220000_transition_based_colocation.sql:5`、`supabase/migrations/20260812190000_initial_backend.sql:407`、`WhereIsMyFriend/Shared/Models/AppDomain.swift:168`、`WhereIsMyFriend/Shared/Models/FriendPresence.swift:86`。

当前存在三种逻辑：

- 首页人数/部分排序：`isSameCityEligible` 不检查更新时间。
- 新的 Here together 卡片：使用 24 小时窗口。
- 实际数据库 `wif_evaluate_direction`：双方位置均必须在 2 小时内。

声称移除两小时限制的旧迁移创建了 `recompute_colocation_for_pair`，但 `wif_evaluate_user` 和其他入口仍调用 `wif_evaluate_direction`。因此即使完整应用本地迁移，实际行为仍旧。

复现：保留两个账号的城市不变，将其中一个位置更新时间改为三小时前，调用实际 `wif_evaluate_user` 后，同城活动 session 被关闭。函数定义检查确认实际函数仍包含 2 小时条件，调用方未引用新函数。

影响：可能出现首页人数、Here together 卡片、通知彼此不一致；用户不移动，仅数据变旧，也可能结束同城 session。不能简单通过全局去掉过期限制来修复，那会把长期未更新的位置误当成实时在场。

建议：统一“已保存城市”“当前可信同城”“通知触发”的语义和窗口，再修改真正生效的 SQL 函数。增加跨越时间边界、保持原城和更新旧记录后的端到端测试。本轮未断言该旧迁移已经在线上部署。

## F3 · P1 · 正式 App 与 Staging TestFlight 无法同时被当前推送路由正确区分（代码确认，线上条件待核验）

位置：`supabase/functions/api/index.ts:104`、`WhereIsMyFriend.xcodeproj/project.pbxproj:767`、`WhereIsMyFriend/Core/RemoteAppRepository.swift` 中 PushTokenBody。

正式 Release 和 Staging TestFlight 使用不同 Bundle ID，但都使用 production APNs 环境，并连接同一 Supabase API。设备注册只发送 sandbox/production，服务端也只按这一维度选唯一的 `APNS_PRODUCTION_BUNDLE_ID`，无法知道 token 属于哪个 App。

如果该配置指向正式 App，Staging TestFlight 的 token 会被登记为正式 App topic；反向配置则正式 App 受影响。APNs topic 应对应 App Bundle ID，不能把“测试用的 App”与“APNs sandbox 环境”混为一谈。依据：[Apple APNs 请求说明](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)。

建议：分开记录/验证 App 变体、APNs 环境和 Bundle ID，服务端维护允许的组合，不接受任意客户端 topic。实机各安装正式 TestFlight 和 Staging TestFlight，分别验证邀请、同城与航班通知。本轮没有读取线上 APNs 配置值，因此不声称某位用户的推送失败已被这项诊断直接证实。

## F4 · P2 · 定位解析失败后，同一有效定位无法重试（已隔离复现）

位置：`WhereIsMyFriend/Core/PlatformServices.swift:221`。

`newestObservation` 在反向地理编码成功前就被推进；失败后不回退。用户再次点击刷新时，如果 Core Location 返回同一份仍在两分钟有效期内的缓存定位，严格的 newerThan 判断会直接丢弃它，不再调用地理编码器。进度一直等待超时。

诊断输出：`geocoder calls = 1, resolving = true, sample still valid = true`；最终 `latestCity = nil`，错误为 `Location is taking too long. Please try again.`。这属于近期防旧结果改动还未覆盖好的边缘路径。

建议：区分“正在解析的最新样本”和“成功提交的最新结果”，允许失败样本的显式重试，同时保留旧异步结果不能覆盖新结果的 generation 防护。

验收：编码失败后重复同一有效样本能重试；已成功提交的重复样本不伪造新鲜时间；旧请求迟到仍不能覆盖新城市。

## F5 · P2 · 删除账号失败时没有给用户可见的错误（代码确认）

位置：`WhereIsMyFriend/Core/AppStore.swift:234`、`WhereIsMyFriend/Features/Profile/ProfileView.swift:236`。

删除操作清空 notice，并使用 `presentsErrors: false`；只处理成功分支。确认对话框关闭后，网络或服务端失败没有专属错误状态或替代提示，用户可能只看到短暂转圈后回到原页面，不知道删除是否完成。

建议：删除必须有明确的成功/失败结果和可重试提示；区分服务端已删除、仅本地 Auth 清理失败的情况。本轮没有实际删除任何账号。

## 其他发布风险（不算已复现 bug）

- 城市群元数据 API 依赖新增 v2 RPC：上线必须先数据库迁移，再 Edge Function，再客户端/隐私文案。直接只部署 API 会破坏定位上传。
- 航班后台查询有全局每日 20 次上限。这是此前明确同意的成本控制，不是代码 bug，但不能作为规模化实时航班追踪承诺；用户和航班变多后应检查公平调度、更新覆盖率和费用。
- 目前工作区有大量未提交、未跟踪的核心代码与迁移。发布前需要固定代码快照和部署清单，清楚区分“本地完成”“服务端部署”“TestFlight 已上传”“商店已上架”。不要清理或覆盖这些用户改动。
- 邀请链接在没有正式受控域名的情况下仍有安装与唤起限制；这不是完整的 Universal Link/未安装落地页体验。

## 建议顺序

1. 先统一城市身份与同城时效规则（F1/F2），一并补全失败场景回归。
2. 修复推送 App 变体路由（F3），用两个真实 App 包做邀请/推送验收。
3. 修复定位重试与删除失败反馈（F4/F5）。
4. 打一个稳定性 TestFlight build，完成真实 Apple 登录、后台跨城、弱网、邀请和推送验证，再扩大城市群匹配或新增功能。
