# Mttone 软件设计文档 (Design)

## 1. 架构概览
Mttone 采用了主流的 **Tauri** 框架架构，分为前端 (UI 层) 与后端 (本地系统调用与业务逻辑层)。
- **前端框架**：React + Vite + TypeScript (响应式布局，优先适配移动端与 iPad 宽屏)
- **后端语言**：Rust (基于 Tauri 2.0 跨端移动端支持)
- **本地存储**：SQLite (`mttone.db`)
- **AI 引擎**：由于主打 iOS 端，后端无法直接依赖系统的 Ollama 守护进程，需将本地 ASR（如 whisper.cpp）与 本地 LLM 推理框架（如 llama.cpp）静态链接或编译入 Rust 后端，以支持在 iOS 沙盒环境内离线运行。

## 2. 系统模块设计

### 2.1 前端 (Frontend - React)
前端主要负责视图渲染和用户交互，核心状态包括会议状态、转写流、发言人列表以及本地模型状态。
- **App.tsx**：应用主入口，包含整个会议录制工作流。
- **状态机管理**：应用在 `idle`（空闲）、`recording`（录音中）、`reviewing`（整理看板）三个核心状态间流转。
- **Tauri IPC 通信**：
  - 通过 `invoke` 调用后端的 Rust 命令。
  - 通过 `listen("transcript-segment")` 接收后端推送的流式转写数据。
- **降级与模拟机制**：在纯浏览器预览环境下，封装了 Mock 逻辑用于脱离 Tauri 环境的纯前端调试。

### 2.2 后端 (Backend - Rust)
后端在 `src-tauri/src` 目录下按业务模块划分为以下核心组件：
- **`audio.rs` (音频模块)**
  - 维护 `RecordingState`。
  - 提供 `start_recording_cmd` 与 `stop_recording_cmd` 命令。
  - 负责与操作系统的麦克风交互及音频流捕获。
- **`diarization.rs` (声纹模块)**
  - 提供 `run_diarization_cmd` 命令。
  - 负责执行端侧声纹分离算法，提取说话人特征（VAD & Speaker Diarization）。
- **`llm.rs` (大语言模型模块)**
  - 维护 `LlmState`，管理与本地 Ollama 进程的通信。
  - 提供获取模型列表 (`get_ollama_models_cmd`)、拉取模型 (`pull_ollama_model_cmd`)、切换模型 (`set_active_model_cmd`) 等运维能力。
  - 提供 `process_text_cmd` 执行“口语净化”等文本处理任务。
- **`db.rs` (数据持久化模块)**
  - 维护 `DbState`。
  - 提供 SQLite 数据库初始化 (`initialize_db_cmd`)。
  - 负责会议元数据 (`create_meeting_cmd`, `get_meeting_details_cmd`) 及声纹片段 (`save_speech_clip_cmd`) 的 CRUD 操作。
- **`rag.rs` (知识库与 RAG 模块)**
  - 提供文档解析、本地向量化存储（如基于 SQLite VSS 或本地向量化库）功能。
  - 负责与音频模块联动：提取关联文档中的专有名词，作为热词字典注入到 ASR 引擎。
  - 负责与 LLM 模块联动：在生成纪要时，检索文档段落，组装 RAG Prompt 进行上下文增强。
- **`main.rs`**
  - 组装上述模块，注册 Tauri Commands，启动应用。

## 3. 核心业务流程

### 3.1 会议录制与转写数据流
1. 用户点击“开始录音”，前端通过 `invoke("start_recording_cmd")` 唤起后端音频捕获。
2. 后端一边录制，一边通过 ASR 引擎识别文本，产生 `transcript-segment` 事件。
3. 后端通过 Tauri Event 将分段数据推送给前端。
4. 前端收到事件后实时更新 `transcript` 状态，驱动 UI 滚动显示。

### 3.2 声纹识别与对齐流程
1. 录音结束后，进入 `reviewing` 状态，生成候选 Speaker 卡片。
2. 前端可播放绑定的短音频切片 (`clipPath`) 供用户试听。
3. 用户或 AI 提供姓名建议后，通过 `bindSpeakerName` 函数将临时 ID (如 Speaker_1) 替换为真实姓名，并在页面上实现“全局对齐”高亮。

### 3.3 大语言模型口语净化流程
1. 在会后整理面板，用户点击“口语净化”。
2. 前端请求后端 `invoke("process_text_cmd")`。
3. 后端将原始文本打包 Prompt 发送至本地 Ollama (如 `gemma4:2b`) 接口。
4. 模型返回平滑后的文本，前端通过 Diff 视图比对渲染（`<del>` 与 `<ins>` 标签），高亮修改部分。

### 3.4 私域知识库与 RAG 工作流
1. 用户在前端上传文档，调用后端 `invoke("upload_document_cmd")`。
2. 后端解析文档文本，将内容分块并向量化存入本地数据库。
3. 创建或延续会议时，用户可绑定相关文档。后端自动提取文档核心术语生成“热词表”，注入本地 ASR 引擎，提高语音识别准确率。
4. 会后请求 LLM 生成纪要时，系统检索绑定文档中的相关背景段落，连同会议转写记录一并发送给本地 Ollama 引擎，生成 RAG 增强的高质量纪要。

## 4. 存储模型
本地 SQLite 核心表结构及关联（概念设计）：
- **Meeting**：会议记录（ID, ParentMeetingID [支持会议延续], 开始时间, 结束时间, 主题, 地点等）
- **SpeechClip**：语音片段（ID, MeetingID, 相对时间, 文本内容, 说话人标识等）
- **SpeakerProfile**：声纹人脉库（ID, 真实姓名, 关联声纹特征指纹等）
- **Document**：私域知识文档表（ID, 文件名, 文本内容, 向量化特征映射等）
- **MeetingDocumentBinding**：会议与文档的多对多映射表（MeetingID, DocumentID）
