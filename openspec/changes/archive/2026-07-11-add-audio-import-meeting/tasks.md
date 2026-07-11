# Tasks: 导入语音文件创建会议

## 1. RecordingViewModel 改造
- [x] 抽取 `runOfflineTranscription(for meetingId: String, audioURL: URL)` 参数化版本
- [x] 原有 `runOfflineTranscription()` 改为调用参数化版本
- [x] 实现 `importAudioFile(from sourceURL: URL)` 方法：
  - 校验文件扩展名（wav, mp3, m4a, aac, flac, ogg, caf）
  - 复制文件到 `Documents/audio_{meetingId}.{ext}`
  - 创建 Meeting 记录（status: `.pendingDiarization`）
  - 设置 `currentMeeting` 和 `meetingStatus = .reviewing`
  - 调用 `runOfflineTranscription(for:audioURL:)` 启动流水线

## 2. MeetingListView UI
- [x] 在 toolbar 添加「导入音频」按钮（`square.and.arrow.down` 图标）
- [x] 添加 `@State isImporting` 控制 `fileImporter` 展示
- [x] 实现 `.fileImporter` modifier：
  - `allowedContentTypes: [.audio]`
  - `allowsMultipleSelection: false`
  - 正确处理 `startAccessingSecurityScopedResource`
  - 调用 `recordingViewModel.importAudioFile(from:)`

## 3. 流水线集成验证
- [x] 确认导入后自动进入 `ReviewingView`，可看到转写中状态
- [x] 离线转录（WhisperKit）和说话人分离（FluidAudio）复用现有参数化流水线
- [x] 编译通过（macOS destination，BUILD SUCCEEDED）

## 4. 边界情况处理
- [x] 不支持的音频格式 → 显示错误提示
- [x] 文件复制失败 → 显示错误提示，不创建 Meeting
- [x] 用户取消文件选择 → 不做任何操作
