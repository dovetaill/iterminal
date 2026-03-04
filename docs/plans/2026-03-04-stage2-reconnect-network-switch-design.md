# Stage2 补全：断线重连与网络切换体验设计（2026-03-04）

## 目标

在既有 Stage2 能力（加密存储、SFTP、片段、Android 软键盘）基础上，补齐“连接韧性”：

- SSH 会话断线后可自动重连
- 网络离线时进入等待状态，网络恢复后自动续连
- 用户可手动触发当前会话重连
- UI 明确反馈当前连接恢复状态

## 设计原则

1. 最小侵入：保留 `SessionController` 作为会话编排中心。
2. 可测试：网络检测通过抽象接口注入，单测可用 fake monitor 驱动。
3. 有界重试：指数退避 + 最大重试次数，避免无限重连风暴。
4. 用户可感知：提供离线 banner、tab 状态图标、终端系统提示行。

## 技术方案

### 1) 网络状态抽象

新增 `lib/services/network_monitor.dart`：

- `NetworkMonitor`：定义 `isOnline()` 与 `onOnlineChanged`
- `ConnectivityPlusNetworkMonitor`：封装 `connectivity_plus`

`SessionController` 仅依赖 `NetworkMonitor`，不直接耦合插件 API。

### 2) 重连状态机（Session 级）

`TerminalSession` 扩展字段：

- `hasEverConnected`
- `reconnectAttempt`
- `nextReconnectAt`
- `waitingForNetwork`
- 新增状态 `SessionStatus.reconnecting`

`SessionController` 维护：

- `Map<String, Timer> _reconnectTimers`
- `Map<String, int> _connectionEpochs`（防旧连接回调污染）
- `Set<String> _closingSessionIds`

核心流程：

- 传输断开或错误 -> `_scheduleReconnect`
- 若离线 -> 标记等待网络，不启动计时器
- 若在线 -> 指数退避后 `_performReconnect`
- 达到最大重试 -> 置 `error`

### 3) SSH 断线探测增强

`SshConnection.connect()` 同时监听：

- `shell.done`
- `client.done`

并用一次性门闩避免重复触发 `onDone`。

## 交互体验

`TerminalPage` 增强：

- AppBar 新增“重连当前会话”按钮
- 网络离线显示顶部 banner
- tab 在 `reconnecting` 时显示 `refresh/wifi_off` 辅助图标
- 状态色新增 `reconnecting = orangeAccent`

## 测试策略

更新 `test/session_controller_test.dart`：

- 自动重连路径（连接断开后恢复）
- 离线等待 + 恢复后续连路径
- 继续覆盖 split/search/close 回归用例

通过 fake `NetworkMonitor` 和 fake `SshConnectionAdapter` 驱动状态流，避免依赖真实平台网络插件。
