# Proposal: 全局声纹跨会议自动匹配

## Why
- 同一人多次参会需重复标注
- 声纹向量未持久化，App 重启丢失
- Embedding key 与 speaker label 不匹配导致查找失败
- 改名时向量未同步保存到联系人

## What Changes

### 声纹向量管理
- Diarization 产出 256 维向量存入 `meetings.embedding_blob`（持久化）
- Embedding key 重映射：`S1` → `Speaker_S1`（匹配 segment speakerId）
- `saveEmbeddingForSpeaker` 内存+DB 双源查找

### 全局声纹匹配
- `fetchContactsWithEmbeddings()` 查全局联系人向量库
- `matchSpeakers()` cosine similarity 比对（阈值 0.7）
- 自定义标签保护：alignment 不覆盖手动分配
- 完成时兜底保存向量

### 联系人管理
- 新增/改名参会人自动创建全局联系人
- `deleteContact` 支持删除（清空关联）
- 人员管理视图删除确认弹窗
- 属性面板固定高度不抖动

### UI 优化
- 新建会议参会人改为弹窗多选
- TextEditor 去掉滚动条，自适应高度
- 拷贝纪要到剪贴板按钮
