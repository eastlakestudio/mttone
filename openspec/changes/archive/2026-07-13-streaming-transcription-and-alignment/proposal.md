# Proposal: 流式转写 + 即时声纹对齐 + 消息通道架构

## Why
- 大量连续回调导致 UI 主线程卡顿，转写中间结果丢失
- 声纹分离需等待 Whisper 全部完成才能对齐，实际声纹分离秒级完成
- 缺乏详细的诊断日志

## What Changes

### 消息通道架构
- 后台 `Task.detached` 负责 AI 分析（Whisper + Diarization）
- 前台 `consumerTask @MainActor` 负责 UI 更新
- `DispatchQueue` 作为消息缓存，解耦生产者和消费者

### 即时声纹对齐
- 声纹分离先行完成（1-2 秒）→ 存入共享变量
- 消费者每收到一批 Whisper 段，立即用共享的声纹结果对齐
- 不等 Whisper 全跑完，UI 实时显示正确 speaker 标签

### 详细日志
- 本地时间戳 HH:mm:ss.SSS 格式
- 每次 callback 触发次数 + 段数 + 文本样例
- 声纹分离 speaker 分布 + 时段样例
- 对齐前后 speaker 切换序列

### 其他修复
- 音频时长：AVAudioPlayer 初始化探测
- 导入时先记录时长再转写
- `finishReview` 保存时长到 DB
- 调试日志弹出窗口（🐞 按钮）
