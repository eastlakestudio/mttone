# Proposal: 统一转写编辑器 + 会议信息侧边栏

## 变更摘要
将回顾页的散落气泡列表替换为统一表格编辑器（`UnifiedTranscriptEditor`），抽取共享 `MeetingInfoSidebar` 供录音页和回顾页共用，并修复声纹标注持久化遗漏和空白文本问题。

## 动机
- 气泡列表无法统一拷贝，界面松散不紧凑
- 录音过程中无法编辑会议基本信息
- 说话人 contactId 未实时持久化到数据库
- 历史会议打开时转写可能为空

## 改动清单

| 文件 | 类型 | 说明 |
|------|------|------|
| `UnifiedTranscriptEditor.swift` | 新增 | 统一表格编辑器：时间 + 说话人标签 + 文本 + 播放 + 合并 |
| `MeetingInfoSidebar.swift` | 新增 | 共享会议信息侧边栏（标题/时间/地点/参会人/说话人匹配） |
| `RecordingView.swift` | 修改 | 添加 sidebar 切换、TranscriptBubble 聊天样式 |
| `ReviewingView.swift` | 修改 | 替换气泡列表为 UnifiedTranscriptEditor、使用共享侧边栏 |
| `RecordingViewModel.swift` | 修改 | 新增 mergeWithPrevious、updateLocalSpeakerLabel、retryOfflineTranscription |
| `DatabaseManager.swift` | 修改 | 新增 updateSpeechClipContact、fetchMeetingGroup、fetchDistinctLocations/Speakers |
| `Models.swift` | 修改 | 新增 audioFileExists、missingAudioReason |

## 功能详情

### 统一编辑器
- 每行：`▶ [02:15] [Speaker_1 ▼] 文本内容 ↑合并`
- 回车在光标处拆分为两行
- 说话人下拉可选已有 + 新建
- 合并按钮将当前行并入上一行（同说话人）
- 不同说话人自动分配不同颜色

### 会议信息侧边栏
- 录音中可切换右侧面板编辑标题/时间/地点/参会人
- 回顾页使用相同组件
- 说话人匹配、发言统计仅在回顾页显示

### 持久化修复
- 重命名说话人后立即逐条写入 contactId
- 历史会议打开时若转写为空，显示「重新运行离线转写」按钮
