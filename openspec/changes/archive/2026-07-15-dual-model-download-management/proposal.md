# Proposal: 双模型下载管理增强

## Summary

增强两个 Whisper 模型（`openai/whisper-large-v3` 和 `openai/whisper-large-v3-turbo`）的下载状态管理：持久化每模型独立下载状态、实现多模型可用性判断以控制会议功能启用/禁用，以及自动选择最优模型。

## Motivation

当前问题：

1. **下载状态不持久化** — `modelDownloadStates` 字典仅在内存中，App 重启后丢失所有下载进度和完成状态
2. **会议可用性判断不准确** — 仅检查单一 `modelVersion` 字符串，无法反映多模型的真实可用情况
3. **无自动模型选择** — 当两个模型均可用时，不会自动切换到更优的 `large-v3`

## Scope

### In Scope

- `ModelDownloadState` 增加 `isDownloaded` 字段，整体实现 `Codable`
- JSON 序列化 `modelDownloadStates` 到 UserDefaults 持久化
- 新增 `anyModelAvailable` / `allModelsUnavailable` 计算属性
- `MeetingListView` 中会议按钮的 `disabled` 条件改为基于多模型可用性
- 首次双模型均下载完成时自动选择 `large-v3`，使用 `hasAutoSelectedModel` 标志位确保仅触发一次
- 启动时清除残留的 `isDownloading=true` 状态（App 被杀后 Task 不可恢复）

### Out of Scope

- App 完全杀死后的断点续传（仅支持 App 活跃/后台运行期间的续传）
- 模型源的更细粒度配置（`useChinaMirror` 保持全局）
- 模型删除功能

## Impact

| 组件 | 影响 |
|------|------|
| `SettingsManager` | 主要改动：新增持久化、计算属性、自动选择逻辑 |
| `SettingsView` | 下载完成回调设置 `isDownloaded=true` |
| `MeetingListView` | `disabled` 条件替换；状态头适配 |
| `WhisperService` | 无改动 |
