# Tasks: 系统配置页 + UI 优化 + LLM 集成

## 系统配置页
- [x] SettingsView: 语音模型管理（选择/下载源/路径/状态）
- [x] SettingsView: 云端 LLM 配置（预设/自定义/Token）
- [x] SettingsView: 会议纪要提示词（中/英文重置）
- [x] 语言切换 EN/中（标题栏胶囊按钮）
- [x] 关于信息（固定底部）
- [x] macOS Form 风格布局
- [x] 提示词与 LLM 合并展示（无分割线）

## LLM 会议纪要
- [x] ReviewingView: AI 纪要按钮
- [x] LLMSummarySheet（结果查看 + 拷贝）
- [x] generateLLMSummary（调用云端 API）
- [x] 未配置时提示

## UI 优化
- [x] 移除说话人匹配（声纹自动匹配后简化）
- [x] 转写语言移到 NewMeetingSheet
- [x] 人员管理按钮移到主页标题栏
- [x] 去除冗余声纹字典链接
- [x] TextEditor 自适应高度 + 隐藏滚动条
- [x] 拷贝纪要按钮
- [x] 人员删除功能
- [x] 新建会议参会人多选弹窗
- [x] 发言人改名自动挂载 contactId
- [x] 重新转写确认弹窗
- [x] 进度百分比修复

## Whisper 语言
- [x] transcribe/transcribeLive 接受 language 参数
- [x] 从 UserDefaults 读取默认语言
- [x] NewMeetingSheet 语言选择（中文/English）
