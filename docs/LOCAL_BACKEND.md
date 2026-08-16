# 可选：本地 Docker Supabase 双用户验证

> 这不是当前的主实施路线，也不是开发或发布的前置条件。主路线是 [远程 Supabase Staging 实施计划](./SUPABASE_PRODUCTION_PLAN.md)：PGlite 做本机 migration 预检，远程 Staging 做 Auth、Edge 和 iOS 集成验证。

只有希望离线运行完整 Supabase stack、反复 reset 临时数据库或复现容器环境问题时，才需要使用本文。它使用本地 Supabase/PostgreSQL，但 iOS 仍连接正式的 `RemoteAppRepository`；数据会跨 App 刷新保存，不是内存 Mock。

## 1. 一次性准备

需要：

- Xcode 26 或更新版本
- Node.js 20 或更新版本
- Docker Desktop、OrbStack 或 Colima（三选一，并确保 Docker-compatible runtime 正在运行）

选择这条可选路线并启动容器 runtime 后，在仓库根目录执行：

```bash
npm install
cp supabase/.env.example supabase/.env.local
npm run backend:start
npm run backend:reset
```

`backend:reset` 会按顺序应用 `supabase/migrations/`，再执行 `supabase/seed.sql`，创建两个仅用于数据库业务验证的 profile：`alice` 和 `bob`。显式 reset 可以保证旧的本地容器也使用当前 schema。

另开一个终端，以强制 JWT 验证模式启动 API：

```bash
npm run backend:serve
```

部署版本和本地版本使用同一套 Supabase Auth JWT 边界；API 中不存在用户名 Debug 登录接口。

## 2. 本地 UI 与真实 Auth 的边界

本地 Supabase 不自动拥有 Apple Provider 配置，因此不能直接使用 seed profile 登录。要验证 UI，普通 Debug 构建继续使用 **Continue with local demo**；要验证真实 Apple/Supabase Auth，请运行 Staging 到真机。只有在你另外为本地 Auth 创建合法用户 JWT 后，才在 Debug scheme 加 `-useRemoteAPI` 并连接：

```text
http://127.0.0.1:54321/functions/v1/api
```

普通 Debug 启动不加 `-useRemoteAPI` 时，仍然使用原来的 Local Demo，不依赖后端。

## 3. 使用 Staging 验证完整交互

1. 两台真机分别使用不同 Apple 账号登录。
2. 第一位用户用第二位用户的 `@username` 发邀请，第二位用户接受。
3. Alice 和 Bob 都进入 Sharing → **Choose a test city** → **New York**。
4. 两边下拉刷新；Friends 会显示对方在 New York，Same-city moments 会各出现一条事件。
5. 任意一边再次选择 New York，不应产生重复事件。
6. 任意一边关闭 City sharing，对方刷新后不再看到该城市，活跃同城会话会关闭。
7. 回到模拟器桌面添加 Widget；主 App 刷新后的远端快照会同步进入 App Group，Widget 显示真实后端数据。

## 4. 自动验证与重置

不需要 Docker 的数据库业务测试：

```bash
npm run backend:test
```

它会在嵌入式 PostgreSQL 中执行完整迁移，并验证邀请、接受、双向同城事件、去重和暂停共享。

Docker 后端已经启动时，重置所有本地数据：

```bash
npm run backend:reset
```

停止本地服务：

```bash
npm run backend:stop
```

## 当前边界

这条纵切已经实现 Supabase Auth session、好友、分享设置、当前城市、同城事件和通知 outbox。下列项目仍保持关闭：

- APNs token 加密和通知投递 worker
- 非 Debug 账号删除前的 Apple token 撤销
- 本地 Apple Provider 的独立配置

它们是上线前的下一阶段，不影响本地双用户 UI 和业务验证。
