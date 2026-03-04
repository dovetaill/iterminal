# Android Stage2 扩展设计（基于 Windows MVP）

## 目标
- 在不推翻第 1 阶段分层的前提下，扩展 Android 关键能力：本地加密存储、收藏连接、SFTP、软键映射。
- 保持 Flutter 主工程不变，后续 Rust 只承接系统/性能痛点。

## 架构扩展
- 新增 `ProfileController`：维护本地账号名、保存连接、片段(snippets)。
- 新增 `SecureVaultService`：将 `VaultData` 序列化后用 AES-GCM 加密，密钥保存在系统安全存储（`flutter_secure_storage`）。
- 扩展 `SshConnectionAdapter`：新增 SFTP 能力（目录读取、文件读取、文件写入），由 `dartssh2` 复用现有 SSH 连接打开 `sftp` 子系统。
- UI 侧新增：
  - `SftpSheet`：目录浏览 + 文件预览 + 片段上传。
  - `SnippetSheet`：片段 CRUD 与发送到当前会话。
  - `MobileQuickKeys`：Android 底部软键栏，支持 Ctrl/Alt/Fn、方向键、功能键与组合键。

## 数据模型
- `SavedSshProfile`: 连接参数 + 收藏标记 + 使用时间。
- `CommandSnippet`: 片段名称、命令内容、收藏状态。
- `VaultData`: 账号名 + 保存连接列表 + 片段列表。
- `SftpEntry`: 远程文件元信息（路径、类型、大小、时间）。

## 关键数据流
1. App 启动：`main.dart` 异步加载设置与加密 vault，初始化控制器。
2. 新建连接：`ConnectDialog` 可从保存连接自动填充，也可更新/新建到加密 vault。
3. SFTP：`TerminalPage -> SessionController -> SshConnection`，结果返回给 `SftpSheet` 呈现。
4. 软键输入：`MobileQuickKeys` 触发后映射到 `Terminal.keyInput/charInput/textInput`。

## 第 1 阶段优化回补
- 设置持久化（主题、配色、字体）；
- 终端输出缓冲上限裁剪，避免长会话内存膨胀；
- 连接超时保护，减少无响应等待时间。
