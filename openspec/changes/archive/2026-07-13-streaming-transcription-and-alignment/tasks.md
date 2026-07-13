# Tasks

## 消息通道架构
- [x] 后台 Task.detached + 前台 consumerTask @MainActor
- [x] DispatchQueue 作为消息缓存
- [x] 移除 Timer 机制，改为每 0.3s 轮询

## 即时声纹对齐
- [x] 声纹分离独立 Task，完成后写入共享变量
- [x] 消费者每次批后检查共享变量，即时对齐
- [x] 对齐完成后 UI 立即显示正确 speaker 标签

## 日志系统
- [x] 统一本地时间 HH:mm:ss.SSS 格式
- [x] 追加模式写入 /tmp/mttone_diag.log
- [x] 每次 callback 触发日志（段数 + 样例）
- [x] 声纹分离时段样例
- [x] 对齐 speaker 分布 + 切换点序列

## 音频时长
- [x] AVAudioPlayer 初始化探测时长
- [x] 导入时先记录时长
- [x] finishReview 保存时长到 DB

## 调试日志窗口
- [x] DebugLogView（🐞 按钮）
- [x] 自动刷新 + 底部滚动
- [x] 关闭按钮

## 其他
- [x] WhisperService 强制 initialize
- [x] 繁简转换 CFStringTransform
- [x] 声纹分离阈值 0.75
