# Privacy Policy / 隐私政策

**Last updated / 最后更新: 2026-07-14**

## English

AuraNote ("听纪") is a local offline meeting minutes application. We take your privacy seriously.

### Data Collection

**AuraNote does NOT collect, store, or transmit any personal data to external servers.** All processing happens entirely on your device:

- **Audio recordings** — Stored locally in the app's sandboxed Documents directory. Never uploaded.
- **Transcriptions** — Generated on-device using WhisperKit. No audio or text leaves your Mac.
- **Speaker voiceprints** — 256-dimension embeddings extracted and stored locally using FluidAudio. Used solely for within-app speaker identification.
- **Meeting data** — Stored in a local SQLite database (`auranote.db`). Never synced to any cloud service.
- **Contact information** — Names, roles, and organizations you enter are stored locally only.

### Permissions

AuraNote requests the following permissions:

| Permission | Purpose |
|------------|---------|
| Microphone | To record meeting audio |
| Speech Recognition | For real-time transcription |
| File Access | To import/export audio files and meeting notes |
| Network | To download speech recognition models (WhisperKit from HuggingFace) |

### Third-Party Services

- **WhisperKit** (OpenAI) — Speech-to-text model downloaded from HuggingFace. No data sent to OpenAI.
- **FluidAudio** — Speaker diarization models. Fully offline.

### Children's Privacy

AuraNote is not intended for use by children under 13.

### Contact

For privacy concerns, contact us at: eastlakestudio@outlook.com

---

## 简体中文

听纪（AuraNote）是一款本地离线会议纪要应用。我们郑重承诺保护您的隐私。

### 数据收集

**听纪不会收集、存储或向外部服务器传输任何个人数据。** 所有处理完全在您的设备上完成：

- **录音文件** — 仅存储于应用的沙盒 Documents 目录，绝不上传
- **转写文本** — 通过 WhisperKit 在设备端生成，音频和文本均不离开您的 Mac
- **声纹特征** — 通过 FluidAudio 提取的 256 维向量仅存储于本地，仅用于应用内发言人识别
- **会议数据** — 存储于本地 SQLite 数据库（`auranote.db`），不与任何云服务同步
- **联系人信息** — 您输入的姓名、角色、组织信息仅存储在本地

### 权限说明

听纪请求以下权限：

| 权限 | 用途 |
|------|------|
| 麦克风 | 录制会议音频 |
| 语音识别 | 实时语音转文字 |
| 文件访问 | 导入/导出音频文件及会议纪要 |
| 网络 | 下载语音识别模型（从 HuggingFace 获取 WhisperKit） |

### 第三方服务

- **WhisperKit**（OpenAI）— 从 HuggingFace 下载语音转文字模型。不向 OpenAI 发送任何数据。
- **FluidAudio** — 声纹分离模型。完全离线运行。

### 儿童隐私

听纪不面向 13 岁以下儿童。

### 联系方式

隐私问题请联系：eastlakestudio@outlook.com
