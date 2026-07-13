# Tasks: 全局声纹到人员的自动匹配

## 数据库层
- [x] contacts 表新增 `voice_embedding BLOB` 列（自动迁移）
- [x] `saveContactEmbedding(contactId:embedding:)` 写入声纹向量
- [x] `fetchContactsWithEmbeddings()` 读取有声纹向量的联系人

## 声纹服务
- [x] `DiarizationOutput` 结构体（segments + speakerEmbeddings）
- [x] `diarizeWithEmbeddings()` 返回声纹向量
- [x] `matchSpeakers()` cosine similarity 跨会议比对
- [x] `cosineSimilarity()` 向量相似度计算

## 自动化匹配
- [x] 声纹分离完成后自动与已知联系人比对
- [x] 置信度 > 0.7 自动应用匹配
- [x] 匹配后保存/更新联系人声纹向量
- [x] consumerTask 对齐时应用 autoMap 重命名

## contact_id 持久化修复
- [x] onSpeakerChanged 回调中查找/创建 Contact 并挂载 contactId
- [x] 历史数据修复（SQL 补齐 503 条缺失 contact_id）
- [x] 全局人员视图可查询到发言记录

## 人员管理优化
- [x] 每条发言增加播放按钮（AudioPlayer seek + playbackEndTime）
- [x] 切换联系人不再误显示保存按钮（比较法 setDirtyIfChanged）
- [x] 属性面板固定高度不抖动（ZStack frame 22px）
