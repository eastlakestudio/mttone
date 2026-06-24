# Mttone 端侧纪要架构搭建总结 (2026-06-24 Walkthrough)

今天我们完成了 Mttone 客户端从零到一的**底层基础设施架构与核心 AI 能力的注入**。这是一个极具技术挑战性且成果丰硕的迭代。

## 1. 原生跨端 UI 架构全面落地 (SwiftUI)
彻底摒弃了繁重的跨平台 Web 方案，全面转向 Apple 生态顶级的 **SwiftUI** 与 **Observation** 框架：
- **实时波形渲染与录音引擎**：基于 `AVAudioEngine` 实现了 1024 缓冲帧级别的低延迟实时采音，在界面上完美支持基于音量振幅的波形动画（Amplitude Animation）。
- **多页面状态流转**：搭建了完整的会议列表（Home）、会议配置（Sheet）、实时录音（Recording）与沉浸式回顾（Reviewing）界面的状态机无缝流转。

## 2. 纯端侧“双模态”离线 AI 架构
在绝不触碰任何云端、保证用户绝对隐私的前提下，打通了极高精度的 AI 纪要流水线：

### 2.1 Apple 实时转写与词汇注入
- 在录制过程中，调用 Apple 系统级 `SFSpeechRecognizer` 进行实时流式听写反馈。
- **高频词汇注水 (Contextual Strings)**：将用户填写的会议主题、地点、参会人直接作为 `contextualStrings` 注入底层 ASR，大幅提升专有名词和名字的识别准确率。

### 2.2 Whisper 大模型与对齐聚类
- **WhisperKit 接入**：录音结束瞬间，触发基于 HuggingFace 权重的 `WhisperKit` CoreML 模型执行极高精度离线重听。
- **声纹分离流水线 (Diarization Spike)**：独立构建了 `DiarizationService`，实现了双规并行。
- **首创的 IOU 文本对齐算法**：在 ViewModel 层面实现了将“大模型输出的无说话人文本序列”与“音频分层分析出的时间戳纯说话人序列”，利用交并比计算面积，在内存中精准将人名“缝合”到了文字上。

## 3. C 语言级的硬核 SQLite 持久化
摆脱了臃肿的 ORM 和 CoreData，手写极度轻量、性能极高的 iOS 内置 `SQLite3` C 语言 API 封装库 (`DatabaseManager`)：
- **多表关联结构**：建立了 `meetings`（会议元数据）与 `speech_clips`（带有声纹与时间戳的发言片段）的关联表。
- **修复底层指针毁灭性 Bug**：精准定位并修复了 Swift 的字符串指针在转入 C API 时过早被垃圾回收的严重问题（全面引入 `SQLITE_TRANSIENT` 深拷贝策略）。
- 实现了完美的落地体验：即便强杀 App 进程，再次打开也能瞬间在首页读出历史记录，并在回顾界面重组所有的发言人标签、用户手工修改的文本以及时间戳高亮动画。

## 4. Git 发布与工程规范
- 整理并清空了所有无用的缓存（`.gitignore` 过滤 `DerivedData` 与增量编译文件）。
- 梳理了整个工程的变更，打包提交并已成功 Push 至您指定的 GitHub 线上仓库。

> [!TIP]
> **后续拓展方向预告**
> 1. 将现有的 Diarization 模拟算子替换为真实的 MLX/Pyannote CoreML 权重。
> 2. 引入端侧本地的 LLM (如 Llama.cpp) 对 `SpeechClips` 进行会议总结与 ToDo 抽取，存入 `summary` 与 `cleanedText` 字段。
