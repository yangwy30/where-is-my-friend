# Across Us 1.0.6（26）— TestFlight 已就绪

2026-09-28，用户明确授权完成服务端部署并上传 TestFlight。

## 发布结果

- Apple 在 23:30 PDT 接收构建，随后处理状态为 **Complete**。
- [构建 1.0.6（26）](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/1b5e2423-6522-4197-94f3-90c5e3af530d) 已关联既有 **Testers / Internal / 1 tester**，可以通过 TestFlight 安装。
- 已保存中英文合并的 What to Test，包含默认全选好友、逐个取消、撤回邀请、系统分享、系统外观、大字号、键盘和历史时长等检查重点。
- App Store Connect 已显示 1.0.5 为 Ready for Distribution，所以本次使用新的 1.0.6 测试版本线。本任务未提交新的 App Store 审核或修改公开商店文案。

## 服务端

- 已部署 `20260929010000_cancel_friend_requests.sql`，生产 API 从 28 更新至 **29**。
- 生产项目：`cdhpaujazbuppbxyhjxq`。API 的 JWT 验证保持开启。
- 部署前备份原 API，并确认本地基线与生产入口及 11 个共享模块完全一致。部署后入口与本地源文件再次比对通过。
- 新 RPC 仅 service_role 可执行；原有数据库函数及其权限均未改变，push-worker、trip-worker 和 ops-monitor 版本均未改变。
- 受保护健康检查返回 **HTTP 200**。没有创建生产测试账号、撤回真实邀请或主动触发推送。
- 私有备份和部署原始记录保存在被 Git 忽略的 `.ops-private/ui-fixes-20260929/`。发布脚本为 `scripts/ops/deploy-ui-review.mjs`。

## 安装包验证

- App 和 Widget 均为 **1.0.6（26）**，生产 Bundle ID、生产后端和 App Group 均已验证。
- Apple Distribution 签名严格校验通过，调试权限关闭；App 的 APNs 环境为 production，Sign in with Apple 保留。
- 本地 Demo 关闭，客户端诊断开启，打包的隐私清单与源码一致。
- 导出 IPA SHA-256：`8190ed27cea017f8c4673d9f61f15cf4ec73e8a092039c3192b7a8bcc08e7b97`。
- 发布源文件哈希保存在 [source-manifest.json](source-manifest.json)，上传时确认未发生变化。
- 归档：`/private/tmp/across-ui-testflight26/AcrossUs-1.0.6-26.xcarchive`。
- 导出包：`/private/tmp/across-ui-testflight26/export-1.0.6/Where Is My Friend.ipa`。

本轮功能验证见 [第二批修复记录](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/ui-fixes-wave2-20260928/README.md)：19 个不同 XCTest 和 27 个不同后端用例均有通过记录。发布准备中再次执行撤回邀请的 3 项数据库用例，通过。

[生产部署验证](backend-verification.json) · [安装包验证](package-verification.json) · [Apple 分发回执](distribution-receipt.json) · [实际保存的测试说明](what-to-test.txt)

![TestFlight 构建与内部测试组](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/releases/1.0.6-26/testflight-build26.png)
