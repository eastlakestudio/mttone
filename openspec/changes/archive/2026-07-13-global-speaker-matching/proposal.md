# Proposal: 全局声纹到人员的自动匹配

## 背景

当前声纹分离（FluidAudio）产出临时标签 Speaker_S0、Speaker_S1，用户需手动逐条映射到全局人员。同一人在多场会议中发言时，每次都需重复操作。

## 技术限制

FluidAudio 不暴露原始声纹向量，无法直接做跨会议声纹比对。但同一会议内的 label 在用户映射后，这些关联关系可跨会议复用。

## 方案：基于历史映射的智能建议

### 核心思路

1. **会议内映射记录**：用户将 Speaker_S0 映射到全局联系人"张三"时，在 `speech_clips` 中写入 `contact_id` 和 `speaker_label`
2. **跨会议关联表**：新建 `speaker_label_mapping` 表，记录 `(meeting_id, speaker_label, contact_id)`，同一 label 在不同会议映射到同一 contact 的次数越多，置信度越高
3. **声纹分离后自动建议**：`alignSpeakerLabels` 完成后，遍历每个 speaker label，查找该 label 在其他会议中「最常」映射到的 contact，自动填充或设为建议

### 关键流程

```
声纹分离完成 (Speaker_S0, Speaker_S1)
  → 查询历史映射表
  → Speaker_S0 之前 3/3 次映射到"张三" → 置信度高 → 自动应用
  → Speaker_S1 之前 0 次映射 → 保持临时标签，等待用户手动绑定
  → UI 高亮显示自动匹配结果，可撤销
```

### 数据库变更

```sql
CREATE TABLE IF NOT EXISTS speaker_label_mapping (
    id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL,
    speaker_label TEXT NOT NULL,  -- Speaker_S0, Speaker_S1
    contact_id TEXT NOT NULL,     -- contacts.id
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
);
```

### UI 变更

- 「发言统计」中自动匹配的 speaker 显示绿色 ✓ + contact 名称
- 右键菜单可「撤销自动匹配」
- 首次匹配的 speaker 显示「建议: 张三」（置信度标签），点击确认

## 目标与非目标

**目标**：
- 同一会议内已映射的 speaker label，再次分离同一 audio 时自动匹配
- 建议跨会议的历史映射关系

**非目标**：
- 不做真实的声纹向量比对（FluidAudio 不支持）
- 不做全自动匹配（保留人工确认环节）
