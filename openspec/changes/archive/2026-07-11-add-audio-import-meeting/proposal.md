# Proposal: 增加导入语音文件创建会议的功能

## 1. 变更摘要
当前 mttone 仅支持通过麦克风实时录制来创建会议。本变更新增从外部导入音频文件创建会议的功能：用户通过系统文件选择器（iOS document picker）选取一个外部音频文件，应用将其复制到内部存储目录，自动创建一个新会议记录，并触发离线转录 + 声纹分离流水线，实现对导入录音的完整转写和分析。

## 2. 动机与背景
- 用户可能有来自其他设备（录音笔、手机通话录音、微信语音等）的音频文件，希望导入 mttone 进行统一管理和转写
- 会议录音不局限于 app 内实时录制，支持导入后可覆盖更多使用场景
- 导入后自动走现有完整的离线转写 + 说话人分离 + 人工校对流程，体验与实时录制一致

## 3. 目标与非目标
**目标：**
- 在 `MeetingListView` 中增加「导入音频文件」入口，通过 iOS `fileImporter` 选择音频文件
- 支持常见音频格式：wav, mp3, m4a, aac, flac, ogg, caf
- 导入的文件复制到 `Documents/audio_{meetingId}.{ext}` 
- 自动创建 Meeting 记录，状态设为 `.pendingDiarization`
- 自动触发离线转写（WhisperService）+ 说话人分离（DiarizationService）流水线
- 完成后进入 `ReviewingView`，用户可进行校对和编辑

**非目标：**
- 不修改现有 WhisperService / DiarizationService 的核心逻辑
- 不涉及批量导入
- 不涉及视频文件中的音轨提取

## 4. 衡量成功的标准
- 用户点击导入按钮，系统文件选择器弹出，可筛选并选择一个音频文件
- 文件被成功复制到 `Documents/` 目录，Meeting 记录正确写入 SQLite
- 自动触发离线转录 + 说话人分离，`ReviewingView` 中可看到转写结果和说话人标签
- 导入的会议在 `MeetingListView` 中正常显示，可重新打开复查
