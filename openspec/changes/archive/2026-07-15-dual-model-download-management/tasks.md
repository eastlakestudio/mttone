# Tasks: 双模型下载管理增强

## 1. SettingsManager 数据模型与持久化

- [x] 1.1 `ModelDownloadState` 增加 `var isDownloaded: Bool = false` 字段，实现 `Codable`
- [x] 1.2 新增 `var hasAutoSelectedModel: Bool` 属性，读写 UserDefaults `has_auto_selected_model`
- [x] 1.3 `save()` 中新增：将 `modelDownloadStates` JSON 编码写入 UserDefaults `model_download_states`
- [x] 1.4 `load()` 中新增：从 UserDefaults 反序列化 `modelDownloadStates`，与文件系统 `.download_complete` 同步后，清除残留 `isDownloading=true`

## 2. SettingsManager 多模型可用性与自动选择

- [x] 2.1 新增 `let allVoices = ["openai/whisper-large-v3", "openai/whisper-large-v3-turbo"]` 常量
- [x] 2.2 新增 `var anyModelAvailable: Bool` 计算属性
- [x] 2.3 新增 `var allModelsUnavailable: Bool` 计算属性 (`!anyModelAvailable`)
- [x] 2.4 新增 `func checkAndAutoSelectModel()`：首次双模型就绪时自动选 `large-v3`
- [x] 2.5 `load()` 末尾调用 `checkAndAutoSelectModel()`

## 3. SettingsView 下载回调适配

- [x] 3.1 `downloadModel()` 成功回调中：`setDownloadState` 时设置 `isDownloaded=true`
- [x] 3.2 `downloadModel()` 成功回调中：调用 `settings.checkAndAutoSelectModel()`

## 4. MeetingListView 会议按钮适配

- [x] 4.1 「开始会议」按钮 `disabled` 条件改为 `!settings.anyModelAvailable`
- [x] 4.2 `statusHeader` 适配多模型状态展示（展示可用模型数量或最佳可用模型名称）

## 5. 验证

- [x] 5.1 验证：下载 `large-v3-turbo` 完成后重启 App，会议按钮可用
- [x] 5.2 验证：两个模型均未下载时，会议按钮禁用
- [x] 5.3 验证：下载 `turbo` 后下载 `large-v3`，完成后自动切换到 `large-v3`
- [x] 5.4 验证：自动选择触发后，用户手动切换到 `turbo`，重启 App 后不会自动切回
- [x] 5.5 验证：下载过程中 App 被杀死，重启后 `isDownloading` 已清除
