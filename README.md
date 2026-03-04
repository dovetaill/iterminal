# iTerminal (Flutter + Rust-ready)

面向 Windows 的终端客户端 MVP，目标是“像 Termius 一样好看好用，并且可维护”。

## 已实现

### 第 1 阶段（Windows MVP）
- Flutter Desktop UI（主题、标签页、分屏、设置页）
- `xterm` 终端渲染与滚动回放
- `dartssh2` SSH 交互 shell（用户名/密码）
- 会话列表、复制/粘贴、搜索命中计数
- 快捷键：
  - `Ctrl+Shift+T` 新建会话
  - `Ctrl+Shift+W` 关闭当前会话
  - `Ctrl+Tab` / `Ctrl+Shift+Tab` 切换标签
  - `Ctrl+Shift+C` / `Ctrl+Shift+V` 复制/粘贴
  - `Ctrl+F` 搜索
  - `Ctrl+Shift+\\` 分屏开关

### 第 2 阶段（Android 核心能力）
- 本地加密存储：设备安全存储 + AES-GCM Vault（连接档案/账号名/片段）
- 收藏连接与连接复用：连接弹窗支持保存/更新/收藏
- SFTP 浏览器：目录浏览、文件预览、将片段上传为远端文件
- 片段管理：新增/编辑/删除/收藏片段，支持一键发送到终端
- 软键盘映射（Android）：Ctrl/Alt/Fn、Esc/Tab、方向键、Home/End、PgUp/PgDn、F1-F12、常见组合键

### 阶段 1 回溯优化
- 主题/配色/字号持久化（`shared_preferences`）
- 终端滚动缓冲内存优化（输出块队列 + 上限裁剪）
- SSH 连接增加超时保护

## 架构

- `lib/state/session_controller.dart`: 会话编排（tabs/split/search/clipboard）
- `lib/services/ssh_connection.dart`: SSH 生命周期与流转发
- `lib/state/settings_controller.dart`: 主题、终端配色、字体设置
- `lib/state/profile_controller.dart`: 账户、保存连接、片段（加密 vault）
- `lib/services/secure_vault.dart`: AES-GCM 加密仓库
- `lib/ui/sftp_sheet.dart`: SFTP 浏览面板
- `lib/ui/mobile_quick_keys.dart`: Android 软键盘映射栏
- `lib/ui/*.dart`: 页面与组件

## 快速开始

1. Install Flutter SDK (Desktop enabled)
2. Run dependency install:

```bash
flutter pub get
```

3. Run on Windows:

```bash
flutter run -d windows
```

4. Run on Android:

```bash
flutter run -d android
```

## 测试

```bash
flutter test
```

## 下一阶段建议

- 增强连接：断线重连、网络切换、跳板机/ProxyJump
- 能力扩展：snippets、命令面板、宏/脚本插件
- Windows 深水区：ConPTY 接入 cmd/pwsh/wsl（可由 Rust 模块承接）

## Rust 接入建议（后续）

保持 Flutter 为主工程，Rust 仅承担“性能与系统能力痛点”：
- ConPTY / 本地 shell 控制
- 高性能日志索引与搜索
- 加密存储与密钥管理底层

可通过 `flutter_rust_bridge` 建立 FFI 边界。
