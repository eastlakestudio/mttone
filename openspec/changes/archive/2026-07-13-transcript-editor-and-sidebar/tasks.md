# Tasks: 统一转写编辑器 + 会议信息侧边栏

## 统一编辑器
- [x] 创建 `UnifiedTranscriptEditor.swift`，表格样式 compact 布局
- [x] 每行显示时间戳（精确到秒）、说话人胶囊（彩色可切换）、文本、播放按钮、合并按钮
- [x] 回车拆分：光标处 `\n` 自动截取，前后文本分别保留
- [x] 说话人下拉菜单：已有说话人列表 + 新建
- [x] 合并按钮：`↑` 将当前行并入上一行（需同说话人）
- [x] 播放按钮：`▶` 跳转到该段 startTime 播放到 endTime

## 会议信息侧边栏
- [x] 创建 `MeetingInfoSidebar.swift`，从 ReviewingView 中剥离共享
- [x] RecordingView 集成 sidebar 切换按钮
- [x] ReviewingView 使用共享组件，删除重复代码

## 持久化修复
- [x] `DatabaseManager.updateSpeechClipContact()` 逐条更新
- [x] `RecordingViewModel.updateLocalSpeakerLabel()` 仅改本行
- [x] 历史会议空白 → 显示「重新运行离线转写」按钮

## 辅助功能
- [x] `Models.audioFileExists` / `missingAudioReason` 诊断属性
- [x] `DatabaseManager.fetchDistinctLocations()` 地点历史联想
- [x] `DatabaseManager.fetchDistinctSpeakers()` 说话人历史联想
- [x] `fixZombieMeetings()` 自动修正卡死会议状态
