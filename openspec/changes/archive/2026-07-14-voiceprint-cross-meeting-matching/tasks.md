# Tasks

## 声纹向量持久化
- [x] `meetings.embedding_blob` 列自动迁移
- [x] `saveMeetingEmbeddings` / `fetchMeetingEmbeddings` DB 方法
- [x] 声纹分离完成后立即存入 meetings 表

## Key 映射修复
- [x] `diarizeWithEmbeddings` 重映射 `S1→Speaker_S1`
- [x] `saveEmbeddingForSpeaker` 内存空时从 DB 加载

## 跨会议匹配
- [x] `fetchContactsWithEmbeddings` 全局查询
- [x] 每个 speaker 打印匹配/未匹配分数日志
- [x] `globalRenameSpeaker` 自动补全 contactId

## 手动标签保护
- [x] consumerTask 对齐前保存非 Speaker_ 前缀标签
- [x] 对齐后恢复手动分配标签

## 联系人管理
- [x] `deleteContact` 清空关联+删除
- [x] 人员管理视图删除确认弹窗
- [x] 属性面板 ZStack 固定高度

## UI
- [x] 新建会议参会人多选弹窗
- [x] TextEditor 去掉滚动条 maxHeight
- [x] 拷贝纪要按钮
