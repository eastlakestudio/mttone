# Spec: 模型下载状态管理

## Requirement: 每模型独立下载状态持久化

`ModelDownloadState` 必须实现 `Codable`，包含 `isDownloaded` 字段。`modelDownloadStates` 字典必须通过 JSON 序列化持久化到 UserDefaults。

#### Scenario: 下载状态在 App 重启后恢复

- **Given** 用户已将 `large-v3-turbo` 下载完成（`isDownloaded=true`）
- **When** App 重启
- **Then** `modelDownloadStates["openai/whisper-large-v3-turbo"].isDownloaded` 为 `true`
- **And** `anyModelAvailable` 为 `true`

#### Scenario: 下载进行中 App 被杀后重启

- **Given** 用户正在下载 `large-v3`（`isDownloading=true`）
- **When** App 被强制杀死后重启
- **Then** `modelDownloadStates["openai/whisper-large-v3"].isDownloading` 被重置为 `false`
- **And** 下载进度被清零

#### Scenario: 文件系统与持久化状态对齐

- **Given** 持久化显示 `isDownloaded=true` 但 `.download_complete` 标记文件被删除
- **When** App 启动执行 `load()`
- **Then** 该模型的 `isDownloaded` 被同步为 `false`

---

## Requirement: 多模型可用性判断

`SettingsManager` 必须提供 `anyModelAvailable: Bool` 和 `allModelsUnavailable: Bool` 计算属性，遍历 `modelDownloadStates` 中所有已注册模型判断可用性。模型「可用」定义为 `isDownloaded=true` 且 `isDownloading=false`。

#### Scenario: 任一模型可用时会议功能启用

- **Given** `large-v3` 已下载，`large-v3-turbo` 未下载
- **When** 检查 `anyModelAvailable`
- **Then** 返回 `true`
- **And** 会议列表页「开始会议」按钮可点击

#### Scenario: 全部模型不可用时会议功能禁用

- **Given** 两个模型均未下载（`isDownloaded=false`）
- **When** 检查 `allModelsUnavailable`
- **Then** 返回 `true`
- **And** 会议列表页「开始会议」按钮被禁用

#### Scenario: 某模型正在下载中不算可用

- **Given** `large-v3` 正在下载（`isDownloading=true`），`large-v3-turbo` 未下载
- **When** 检查 `anyModelAvailable`
- **Then** 返回 `false`

---

## Requirement: 首次双模型就绪自动选择

当两个模型首次均下载完成时，系统必须自动将 `selectedVoice` 设置为 `"openai/whisper-large-v3"`。此自动选择仅触发一次，之后用户手动切换模型不受干预。

#### Scenario: 两个模型首次均完成时自动选择 large-v3

- **Given** `large-v3` 已下载，`large-v3-turbo` 刚刚下载完成（首次双模型就绪）
- **And** `hasAutoSelectedModel` 为 `false`
- **When** `checkAndAutoSelectModel()` 被调用
- **Then** `selectedVoice` 被设置为 `"openai/whisper-large-v3"`
- **And** `hasAutoSelectedModel` 被设置为 `true`

#### Scenario: 自动选择仅触发一次

- **Given** `hasAutoSelectedModel` 已为 `true`，用户手动切换到 turbo
- **When** 再次触发 `checkAndAutoSelectModel()`
- **Then** `selectedVoice` 保持用户手动选择的 turbo，不被覆盖

#### Scenario: App 重启后不再重复自动选择

- **Given** `hasAutoSelectedModel` 持久化为 `true`
- **When** App 重启
- **Then** 不执行自动模型选择
