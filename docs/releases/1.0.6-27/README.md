# Across Us 1.0.6（27）— TestFlight 已就绪

2026-09-29 用户授权上传，并明确授权 Xcode 自动管理签名。

## 发布结果

- Apple 已接收并处理完成，状态 **Complete**。
- [构建 1.0.6（27）](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/86a1b3d1-648c-4d4a-8001-669d53eab63b) 已关联原有 **Testers / Internal / 1 tester**，可通过 TestFlight 安装。
- 中英文 What to Test 已保存，覆盖 F14、城市搜索、F10、F24、F16。
- 本轮只上传客户端测试构建，没有提交 App Store 审核或重新部署后端。

## 核验

- App 与 Widget 均为 **1.0.6（27）**；正式签名严格校验通过，调试权限关闭。
- 生产后端、App Group、production APNs、Sign in with Apple、Demo 关闭及隐私清单均已核验。
- 归档准备时的源文件清单与上传时源文件一致。
- 实际 IPA SHA-256：`dd3cdb49a5af5f9a5216ddb66e8c85278d7dd29a610d973b26fde83ce91afa99`。
- 归档：`/private/tmp/across-ui-testflight27/AcrossUs-1.0.6-27.xcarchive`。
- IPA：`/private/tmp/across-ui-testflight27/export/Where Is My Friend.ipa`。
- 本轮功能验证：[第三批修复记录](../../ui-fixes-wave3-20260929/README.md)，11 个不同 XCTest 用例均有通过记录。

## 签名恢复记录

最初导出遇到 No Accounts / No iOS Distribution certificate；用户恢复登录后，命令行仍未识别账号，改用 Xcode Organizer。自动签名曾被自动审批阻止；用户明确授权后，成功使用 Cloud Managed Apple Distribution（2027-08-16 到期）及 App / Widget 各自的 Store Provisioning Profile 完成签名和上传。关闭了自动修改版本号，未更换构建号。初始归档检查与截图保留为历史诊断，不代表最终发布状态。

[安装包核验](package-verification.json) · [Apple 分发回执](distribution-receipt.json) · [测试说明](what-to-test.txt) · [源文件清单](source-manifest.json)

![TestFlight 构建和内部测试组](/Users/wangyang/.gemini/antigravity/where_is_my_friend/docs/releases/1.0.6-27/testflight-build27.png)
