# Windows Terminal MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Windows 上交付一个“像终端”的 Flutter 客户端：支持 SSH 交互 shell、标签页、分屏、会话列表、搜索、复制粘贴、快捷键与基础设置。  
**Architecture:** 主工程用 Flutter（UI/状态/交互），网络连接采用 dartssh2，终端渲染采用 xterm。业务层按 `UI -> SessionController -> SshConnection` 分层，便于后续 Android 与 Rust 扩展。  
**Tech Stack:** Flutter 3.x, Dart, `xterm`, `dartssh2`, Material 3。

## 范围与分期

### 阶段 1（本次落地）
- Windows MVP：SSH shell 交互、标签页、分屏、设置、会话列表、基础快捷键。
- 不做账号系统、不做 SFTP、不做 ConPTY，本地 shell 和插件系统后续扩展。

### 阶段 2+（预留接口）
- Android 软键盘映射、断线重连策略、收藏连接、SFTP。
- ProxyJump、端口转发、片段/宏、同步。
- Windows ConPTY、串口、Telnet。

## 关键设计决策

1. 会话对象与连接对象解耦：`TerminalSession` 只承载 UI/状态，`SshConnection` 负责 SSH 生命周期。  
2. `SessionController` 管理 tab/split/search/clipboard 的交互编排，降低 Widget 复杂度。  
3. 搜索先做“文本结果计数与导航索引”（低风险、可维护），高亮命中后续增强。  
4. 所有连接错误落到会话缓冲区并显式显示状态，避免静默失败。  
5. 主题与字体集中在 `SettingsController`，确保跨端一致体验。

## 任务拆分（可执行）

### Task 1: 工程骨架与依赖
**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`, `lib/app.dart`

### Task 2: 模型与连接层
**Files:**
- Create: `lib/models/ssh_profile.dart`
- Create: `lib/models/terminal_session.dart`
- Create: `lib/services/ssh_connection.dart`

### Task 3: 状态控制器
**Files:**
- Create: `lib/state/session_controller.dart`
- Create: `lib/state/settings_controller.dart`

### Task 4: UI 页面与组件
**Files:**
- Create: `lib/ui/connect_dialog.dart`
- Create: `lib/ui/session_list_drawer.dart`
- Create: `lib/ui/terminal_page.dart`

### Task 5: 测试与文档
**Files:**
- Create: `test/session_controller_test.dart`
- Create: `test/settings_controller_test.dart`
- Create: `README.md`

## 验收标准（阶段 1）

- 能创建 SSH 会话并与远端 shell 交互。
- 支持多标签页切换与关闭。
- 支持双栏分屏查看两个会话。
- 支持右键复制/粘贴、`Ctrl+Shift+C/V`、`Ctrl+Tab`、`Ctrl+Shift+T/W`。
- 支持搜索输入后返回命中数。
- 设置页可切换主题模式、终端配色、字体大小。
