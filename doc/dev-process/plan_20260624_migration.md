# Mttone 架构转型：从 Tauri 迁移至 SwiftUI 原生应用

**日期标签：** 2026-06-24_1859
**决策结论：**
- 技术路线：**方案 B — 全 Swift 重写**（放弃 Rust Core + UniFFI 方案）
- 最低 iOS 版本：**iOS 17+**（使用 `@Observable` 宏、NavigationStack 等最新特性）
- 项目位置：在 `mttone/MttoneApp/` 下创建 Xcode 项目

## 核心架构

```
SwiftUI 表现层 → Swift ViewModel → Swift Services → SQLite3 (内置)
```

- 音频录制：`AVAudioEngine` + `AVAudioSession`
- 语音转写：`SFSpeechRecognizer`（Apple 原生，先跑通链路，后续可替换 whisper.cpp）
- 数据库：SQLite3 C API（iOS 内置，零依赖）
- LLM 通信：URLSession（调用本地 Ollama）
- UI 框架：SwiftUI（iOS 17+）

## 阶段划分

- **阶段 0**：Xcode 项目脚手架 + 目录结构
- **阶段 1**：核心链路（创建会议 → 录音 → 实时转写）
- **阶段 2-5**：与原计划一致，全部用 Swift 原生实现
