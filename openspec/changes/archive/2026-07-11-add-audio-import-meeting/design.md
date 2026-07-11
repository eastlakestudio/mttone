# Design: 导入语音文件创建会议

## 1. 架构概览

### 1.1 现有流程 vs 新增流程

**现有流程（实时录制）：**
```
MeetingListView → NewMeetingSheet → RecordingView (AVAudioEngine)
  → 停止录制 → audio_{id}.wav → 离线转录 + 说话人分离 → ReviewingView
```

**新增流程（导入文件）：**
```
MeetingListView → fileImporter (文档选择器) → 复制文件到 Documents/
  → 创建 Meeting (status: .pendingDiarization) → 离线转录 + 说话人分离 → ReviewingView
```

两套流程在离线转录 + 说话人分离阶段完全复用现有代码。

### 1.2 改动点概览

| 文件 | 改动 |
|---|---|
| `MeetingListView.swift` | 新增「导入音频」按钮，触发 `fileImporter` |
| `RecordingViewModel.swift` | 新增 `importAudioFile(url:)` 方法，处理文件复制、Meeting 创建、流水线触发 |
| `Models/Models.swift` | 无改动（现有 Meeting 模型已满足需求） |
| `DatabaseManager.swift` | 无改动（现有 `createMeeting` / `updateMeeting` 已满足需求） |
| `WhisperService.swift` | 无改动（现有 `transcribe()` 方法接受文件 URL） |
| `DiarizationService.swift` | 无改动（现有 `diarize()` 方法接受文件 URL） |

## 2. 详细设计

### 2.1 文件导入 UI

在 `MeetingListView` 的 toolbar 或列表中新增导入按钮。点击后调起 iOS 原生的 `fileImporter` modifier（iOS 17+）：

```swift
// MeetingListView.swift
@State private var isImporting = false

// 按钮触发
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button { isImporting = true } label: {
            Image(systemName: "square.and.arrow.down")
        }
    }
}

// fileImporter modifier
.fileImporter(
    isPresented: $isImporting,
    allowedContentTypes: [.audio],
    allowsMultipleSelection: false
) { result in
    guard let url = try? result.get().first else { return }
    let gained = url.startAccessingSecurityScopedResource()
    defer { if gained { url.stopAccessingSecurityScopedResource() } }
    await recordingViewModel.importAudioFile(from: url)
}
```

### 2.2 `RecordingViewModel.importAudioFile(from:)` 

```swift
func importAudioFile(from sourceURL: URL) async {
    let meetingId = UUID().uuidString
    let ext = sourceURL.pathExtension.lowercased()
    let allowedExts = ["wav", "mp3", "m4a", "aac", "flac", "ogg", "caf"]
    guard allowedExts.contains(ext) else {
        errorAlert = "不支持的音频格式: .\(ext)"
        return
    }

    // 1. 复制文件到 Documents/audio_{meetingId}.{ext}
    let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let destURL = destDir.appendingPathComponent("audio_\(meetingId).\(ext)")
    try? FileManager.default.copyItem(at: sourceURL, to: destURL)

    // 2. 创建 Meeting 记录
    let fileName = sourceURL.lastPathComponent
    let meeting = await databaseManager.createMeeting(
        id: meetingId,
        title: fileName.replacingOccurrences(of: ".\(ext)", with: ""),
        location: "外部导入",
        audioPath: destURL.path
    )

    // 3. 更新状态并启动转录流水线
    await databaseManager.updateMeetingStatus(meetingId, status: .pendingDiarization)
    currentMeeting = meeting
    meetingStatus = .reviewing

    // 4. 触发离线转录 + 说话人分离（复用现有逻辑）
    await runOfflineTranscription(for: meetingId, audioURL: destURL)
}
```

### 2.3 现有 `runOfflineTranscription` 的重构考虑

当前 `RecordingViewModel.runOfflineTranscription()` 的方法签名是：

```swift
func runOfflineTranscription() async { ... }
```

它内部读取 `currentMeeting` 来获取 `audioPath`。导入场景下需要先设置 `currentMeeting` 再调用，因此需要封装一个接受 `meetingId` 和 `audioURL` 参数的重载版本，使逻辑更清晰。或者直接在 `importAudioFile` 方法里完成所有设置后调用原有的 `runOfflineTranscription()`。

**推荐方案**：将 `runOfflineTranscription` 核心逻辑抽取为接受参数版本：

```swift
private func runOfflineTranscription(for meetingId: String, audioURL: URL) async {
    // 并行执行 WhisperKit 转录和 FluidAudio 说话人分离
    async let transcription = whisperService.transcribe(audioURL: audioURL, meetingId: meetingId)
    async let diarization = diarizationService.diarize(audioURL: audioURL)
    let (transcripts, diarizedSegments) = try await (transcription, diarization)
    
    let aligned = await alignSpeakerLabels(transcripts: transcripts, diarization: diarizedSegments)
    await MainActor.run {
        transcriptSegments = aligned
    }
    await databaseManager.updateMeetingStatus(meetingId, status: .completed)
}

// 原有的实时录制完成后调用
func runOfflineTranscription() async {
    guard let meeting = currentMeeting,
          let path = meeting.audioPath else { return }
    let url = URL(fileURLWithPath: path)
    await runOfflineTranscription(for: meeting.id, audioURL: url)
}
```

## 3. 数据流

```
User taps import → fileImporter → sourceURL (security-scoped)
  → copyFile to Documents/audio_{id}.{ext}
  → databaseManager.createMeeting(...)
  → runOfflineTranscription(for:audioURL:)
    → WhisperService.transcribe()  → [TranscriptSegment]
    → DiarizationService.diarize() → [DiarizedSegment]
    → alignSpeakerLabels()         → assigned speaker labels
  → UI 更新 transcriptSegments → ReviewingView
```

## 4. 安全与权限
- 使用 `URL.startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` 正确处理 iOS 安全作用域资源
- 文件复制到应用沙盒内，不持外部引用
- 仅允许常见音频格式，避免非预期文件类型导入
