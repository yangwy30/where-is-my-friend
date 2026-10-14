# 同城卡片仅手动展开 — Complete

2026-10-10。用户要求 Friends 首页的 Same-city friends 卡片不再自动展开，折叠后也不能被后台刷新或页面重建重新打开。

## 修复

`SameCityReunionCard` 原先在事件 ID 的初始监听中设置 `expanded = true`。用户点击卡片标题折叠时保留事件 ID；页面重建后，旧事件再次触发初始监听，导致卡片重新展开。

现在默认折叠，只有用户点击卡片标题才能展开。事件选择变化只重置详情中的好友选择。保留同城通知的事件定位、数据刷新及失效说明，打开通知后也由用户决定是否展开详情。没有新增设置或改变共享范围。

## 验证

iPhone 18 Pro / iOS 27.0 上 3 项 XCTest 全部通过：手动展开/关闭；折叠后刷新、切换 Tab、前后台切换；同城链接从其他 Tab 打开、重复打开和冷启动；用户手动展开后仍可查看失效事件说明。

本次改动尚未上传 TestFlight，现有 1.0.6（27）不包含本修复。

原始结果：`/private/tmp/across-manual-same-city-20261010.xcresult`。摘要见 [test-results.json](test-results.json)。`git diff --check` 通过。

- [刷新及前后台切换后仍折叠](evidence/manual-same-city-collapsed-after-refresh-and-foreground.png)
- [重复打开事件链接仍折叠](evidence/manual-same-city-event-replay-stays-collapsed.png)
- [冷启动事件链接仍折叠](evidence/manual-same-city-cold-link-stays-collapsed.png)
