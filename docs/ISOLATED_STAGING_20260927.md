# 独立云端测试环境与公网验证

## 交付范围

- 新建项目：`across-us-isolated-staging`，ref `tyeeulfevixeuttmrzeq`，数据库区域 `us-east-2`，现有 Free 组织，无套餐升级。
- 原项目 `cdhpaujazbuppbxyhjxq` 虽名为 staging，实际供正式 App 使用。本轮未对它部署、写测试数据或加压。
- 为释放免费名额，用户明确同意在备份后暂停旧 TripFlights 项目 `zgqjctiuycrhwrstorxw`；`project-hyperlocal` 原本已暂停。
- 新环境已应用 22 个迁移，API 已部署，测试配置和生产配置分离。只部署 API，没有部署推送/航班 worker，没有复制生产 Secret 或真实用户数据。
- Staging 原生 Apple provider 已配置为 `com.yangwy30.whereismyfriend.staging`。此次真实会话验证使用 Supabase 密码登录，不代表已通过 Apple 真机登录或真实 APNs 送达验收。
- 本轮没有提交 App Store 或上传 TestFlight。

## 旧网页备份

本机私有目录 `.migration-backups/tripflights-bfxqos/`，已被 Git 忽略：

- 全部 5 张业务表：7 个行程、26 位参与者、31 条航班、2 条备注、0 条 Web push subscription。
- 数据快照 SHA-256：`292ec7a1019df0e78127ac8884ae8d02c379c2925cce23182fe0a35aadd8fee6`。
- 数据库结构元数据、4 个 Edge Function 源码、项目/Auth/REST 配置及 Secret 名称/指纹。
- 当时 Auth 用户与 Storage 对象均为 0。21 个备份文件完成校验，备份目录/文件分别限制为 0700/0600。
- 旧网页恢复后重新导出校验，5 张业务表的全部记录与暂停前备份逐项一致。
- 保留旧云项目，未删除。Secret 指纹不等于 Secret 明文，因此本地文件不能称为完整灾难恢复包；恢复应优先使用原项目的恢复功能。

## 配置隔离

`Staging` / `Staging TestFlight` 通过 `Config/Staging.xcconfig` 读取独立配置。默认未配置时停止连接，生成的本机配置写入忽略文件 `Config/Staging.local.xcconfig`。公开客户端 key 可以进入测试 App，管理密钥和数据库密码始终只在私有文件或进程内。

运行时再次校验测试 App 的 API/Auth 地址一致，并拒绝全部原有项目地址、错误路径、URL 凭据和查询片段。正式 Release 地址未改动；主 checkout 的 Supabase link 仍指向原正式项目。

实际编译的 Staging 包已核对：bundle ID 为 `com.yangwy30.whereismyfriend.staging`，显示名称 `Across Us Test`，API 和 Auth URL 都指向新项目。

## 数据集与测量范围

- 20 个真实 Supabase Auth 虚拟账号，各有 19 位测试好友，每位好友 3 份计划；每账号可看到 57 条好友计划、57 条相聚记录、一个 5 人 Trip。
- 负载路径：真实公网 → Supabase gateway → Edge API → 真实 Auth 校验 → PostgREST → PostgreSQL。
- 基线：1 / 5 / 10 / 20 个不同账号，每个账号一次只执行一个请求。
- 突发：相同账号每人 5 条并行浏览流程，最多 **20 个账号、100 个在途请求**，不是 100 或 1,000 个不同用户。
- 每条浏览流程重复 3 次，每轮读取 Friends、相聚概览、好友计划第一页、Trips。每条响应均校验账号和预期数据数量；错误或限流会停止进一步加压。
- API 已部署并完成账号准备后才测量，以热路径为主；不宣称测出了冷启动上限。没有模拟真实用户思考时间，也不是长时间 soak test。

## 测试结果

完整原始汇总：[isolated-hosted.json](load_tests/2026-09-27/isolated-hosted.json)。本轮各轮共 **8,544 个测量请求，最终 HTTP 响应与数据校验零失败**；这不代表没有内部重试，也不代表生产千人容量保证。

下表均取每轮最高档的单请求 p95：

| 场景 | 账号数 / 最大在途请求 | 请求数（最高档） | p95 |
| --- | ---: | ---: | ---: |
| 优化前基线 | 20 / 20 | 240 | 672ms |
| 优化前突发，自动选区 | 20 / 100 | 1,200 | 1,854ms |
| 区域实验，指定 us-east-1 | 20 / 100 | 1,200 | 3,239ms |
| 自动选区再次突发 | 20 / 100 | 1,200 | 5,370ms |
| 优化后基线 | 20 / 20 | 240 | 578ms |
| 优化后突发，自动选区 | 20 / 100 | 1,200 | 1,338ms |

连续高峰的尾延迟波动明显，不能只挑最快一次下结论。优化后突发仍出现约 5.31 秒的最慢请求。强制区域没有显示可靠收益，并且会失去自动区域故障转移，因此未给 App 固定执行区域；默认执行区域由响应头确认是 `us-west-1`，数据库在 `us-east-2`。

区域机制及故障转移边界参考 [Supabase Regional Invocations](https://supabase.com/docs/guides/functions/regional-invocation)。费用与项目名额规则参考 [Supabase billing](https://supabase.com/docs/guides/platform/billing-on-supabase)。

## 发现并修复

普通首页刷新向 `/v1/auth/bootstrap` 发请求时，鉴权已经解析了有效 App profile，却仍再调用一次 `wif_ensure_app_user`。这多一次数据库往返，并进入同账号初始化锁。

已改为：已有 profile 且没有传入新显示名称时直接读取 snapshot；首次登录和明确传入名称时保持原初始化逻辑。每次请求的真实 Auth 验证和账号解析仍执行，未引入跳过鉴权的路径。

此 API 优化只部署到新测试项目。正式后台仍需另行发布。表中的前后数值是此次观察结果，受环境波动影响，不能把全部延迟变化归因于该改动；确定减少的是已有账号普通刷新的一次 RPC。

## 功能、队列和本地回归

- 云端 10 项计划/权限检查通过，压力测试后再次通过：未登录拒绝、私有计划不可读、越权编辑拒绝、身份注入拒绝、日期交集正确、分享可见、通知详情定位、旧版本编辑冲突、撤销后的列表与详情消失。
- 优化后新建临时账号验证首次初始化、明确名称更新和常规刷新身份保持，3 项通过；该临时账号已删除。
- 云端通知队列：100 条虚拟设备任务全部被领取，100 个唯一 delivery ID；关闭一个账号的提醒后，5 条设备任务失效，其余 95 条仅模拟数据库确认。未调用 APNs、未发送真实通知。
- `SKIP LOCKED` 的并发读取可能返回空批次；测试继续排空后核对全量，而不是错误地把首轮空批次当成丢任务。
- 132 项后端测试通过，186 项 iOS 单元测试通过；Staging 未配置及实际配置后均成功编译。

## 清理与后续

20 个负载测试账号已按本次 run marker 逐一清理，本机凭据文件已替换为清理回执；临时计划和虚拟设备队列也已清理。项目、迁移、API 和隔离配置保留供后续使用。私有备份和测试凭据不在 Git 中。

后续优先级：为高峰尾延迟补齐 Auth / RPC / SQL 分段计时和持续采样，再验证更大数据集、更多不同账号及真实 Apple/APNs 链路。本次结果只覆盖本数据集与请求模式，不承诺任意规模在线用户容量。

最终运行状态：正式 App `cdhpaujazbuppbxyhjxq` 与旧 TripFlights `zgqjctiuycrhwrstorxw` 均为 `ACTIVE_HEALTHY`；新测试项目 `tyeeulfevixeuttmrzeq` 为 `INACTIVE`，其结构、API 与配置保留。原 `project-hyperlocal` 仍为 `INACTIVE`。

考虑到旧网页仍在使用，本轮测试结束后已恢复旧服务，以暂停测试环境的方式保留免费名额。下次需要公网测试时，再明确安排两个环境的启停窗口；不能同时启用三个免费项目。

隔离项目已部署的 API 源码下载后与工作区逐字节一致，SHA-256 为 `198f4d02bab4183001b694e4aed2b13ee7ba1937f57620598b5a26cc952c9937`。
