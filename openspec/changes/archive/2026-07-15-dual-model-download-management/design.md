# Design: 双模型下载管理增强

## Architecture Overview

```
SettingsManager (persisted)
├── modelDownloadStates: [String: ModelDownloadState]  ← JSON → UserDefaults
│   ├── "openai/whisper-large-v3"       → {isDownloading, progress, error, isDownloaded}
│   └── "openai/whisper-large-v3-turbo" → {isDownloading, progress, error, isDownloaded}
│
├── hasAutoSelectedModel: Bool   ← UserDefaults (防止重复自动选择)
│
├── [computed] anyModelAvailable: Bool
├── [computed] allModelsUnavailable: Bool
└── func checkAndAutoSelectModel()
```

## Data Model

### ModelDownloadState (Codable)

```swift
struct ModelDownloadState: Codable {
    var isDownloading: Bool = false
    var progress: Double = 0.0
    var error: String? = nil
    var isDownloaded: Bool = false   // NEW
}
```

### Persistence Keys

| Key | Type | Purpose |
|-----|------|---------|
| `model_download_states` | JSON Data | `[String: ModelDownloadState]` 字典 |
| `has_auto_selected_model` | Bool | 自动选择已触发标志 |

## Key Flows

### 1. App Launch (`load()`)

```
load()
  ├─ 从 UserDefaults 反序列化 modelDownloadStates
  ├─ 与文件系统同步: 遍历每个模型目录检查 .download_complete
  │   ├─ 文件存在 → isDownloaded = true
  │   └─ 文件不存在 → isDownloaded = false
  ├─ 清除残留: 所有 isDownloading = true → 重置为 false
  ├─ 从 UserDefaults 读取 hasAutoSelectedModel
  └─ checkAndAutoSelectModel()
```

### 2. 下载完成 (`downloadModel()` 成功回调)

```
downloadModel() success
  ├─ 写入 .download_complete 标记文件
  ├─ setDownloadState(isDownloaded=true, for: voice)
  ├─ WhisperService.reset()
  └─ checkAndAutoSelectModel()
```

### 3. 自动选择 (`checkAndAutoSelectModel()`)

```
checkAndAutoSelectModel()
  ├─ hasAutoSelectedModel == true? → return (已触发过)
  ├─ large-v3.isDownloaded && turbo.isDownloaded?
  │   └─ YES → selectedVoice = "openai/whisper-large-v3"
  │            hasAutoSelectedModel = true
  │            save()
  └─ NO → 不操作，等待下次触发
```

### 4. 会议可用性判断

```
anyModelAvailable:
  for voice in allVoices:
    state = downloadState(for: voice)
    if !state.isDownloading && state.isDownloaded → return true
  return false

MeetingListView:
  .disabled(!SettingsManager.shared.anyModelAvailable)
```

### 5. 下载取消

```
cancel download
  ├─ downloadTask?.cancel()
  ├─ setDownloadState({isDownloading:false}, for: voice)
  └─ 删除 .download_complete 标记文件 (如果之前存在)
       → SettingsView 中已有此逻辑，保持不变
```

## State Alignment Strategy

`isDownloaded` 在持久化中作为快速判断源，但文件系统（`.download_complete` 标记文件）作为真相源：

- **写入**: 下载完成时同时写入标记文件 + 持久化 `isDownloaded=true`
- **读取**: load() 时以文件系统为准同步持久化状态
- **运行时**: 直接读 `isDownloaded`，O(1) 判断

## File Changes

| File | Changes |
|------|---------|
| `SettingsManager.swift` | `ModelDownloadState` 加 `isDownloaded` + `Codable`；新增 `hasAutoSelectedModel` 持久化属性；新增 `anyModelAvailable`/`allModelsUnavailable` 计算属性；新增 `checkAndAutoSelectModel()`；`load()`/`save()` 增加持久化逻辑 |
| `SettingsView.swift` | `downloadModel()` 成功回调中设置 `isDownloaded=true`；`downloadModel()` 中触发 `checkAndAutoSelectModel()` |
| `MeetingListView.swift` | `disabled` 替换为 `!settings.anyModelAvailable`；`statusHeader` 适配多模型状态展示 |
