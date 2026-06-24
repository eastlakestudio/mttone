# Mttone 开发阶段 1：数据持久层重构 (Walkthrough)

## 1. 变更概述
在本次开发中，我们完成了**阶段一 (Phase 1)** 的核心目标，成功对底层的 SQLite 数据表结构及对应的 Rust Tauri Commands 进行了重构，为后续的“会议延续”以及“知识库 RAG”功能打下了坚实的数据基础。

## 2. 详细变更记录

### 2.1 数据库结构升级 (`src-tauri/src/db/schema.sql`)
- **扩展会议元数据**：在 `meetings` 表中成功加入了 `parent_meeting_id`（支持上下午等延续性会议的绑定）以及 `location` 字段。
- **新增知识库表结构**：
  - 创建了 `documents` 表，用于存储私域知识库文档的元数据（文件名、路径、提取文本）。
  - 创建了多对多映射表 `meeting_document_bindings`，支持将多个背景文档关联到特定会议中。

### 2.2 后端接口重构 (`src-tauri/src/db/mod.rs` & `main.rs`)
- **数据模型更新**：更新了 Rust 侧的 `MeetingInfo` 结构体，添加了对应的新增字段。
- **会议记录接口升级**：修改了 `create_meeting_cmd` 与相关查询接口的 SQL 语句，能够正确地读写 `parent_meeting_id` 和 `location`。
- **新增文档管理接口**：新增了以下 Command 接口并在 `main.rs` 中完成注册，供前端随时调用：
  - `add_document_cmd`
  - `get_documents_cmd`
  - `bind_document_cmd`
  - `get_meeting_documents_cmd`

### 2.3 前端 UI 适配 (`src/App.tsx`)
- 拦截了原有的“开始新录音”点击逻辑。
- 新增了 **新建/延续会议录制** 的配置弹窗。用户现在可以在开始录音前输入：
  - 会议主题
  - 会议地点
  - 参会人
  - 延续历史会议 ID
- 提取这些弹窗状态并在录音前调用 `invoke("create_meeting_cmd")` 完成落库。

## 3. 验证情况
- [x] Schema SQL 语法验证通过，能够正确构建表关系及外键约束。
- [x] Rust 核心业务层（Command 函数封装）编译与逻辑检验通过。

## 4. 后续步骤
目前底层的数据模型已经就绪。接下来我们将进入**阶段 2：私域知识库 (RAG) 基建与文档管理**，在后端加入 `rag.rs` 模块处理文档解析和向量化存储，并在前端接入真实的知识库管理面板。
