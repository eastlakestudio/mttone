# Tasks: 全局人员与声纹管理 + 编辑器优化

## 全局人员管理
- [x] Contact 模型增加 `role` / `company` 字段 + `displayName`
- [x] DB `contacts` 表迁移（`ALTER TABLE ADD COLUMN`）
- [x] `fetchAllContacts` / `saveContact` / `fetchContact(byName:)` 更新
- [x] `fetchSpeechClipsGroupedByMeeting` 新查询（JOIN meetings 表）
- [x] 删除 `GlobalSpeakerListView.swift` + `SpeakerDetailView.swift`
- [x] `PersonnelManagementView` 双列布局（左人员列表+属性 / 右会议分组发言）

## 参会人选择
- [x] 搜索框实时筛选全局人员
- [x] `NewContactSheet` 面板（人名/角色/组织）
- [x] 新建说话人自动添加为参会人（`attendeesString` Binding 同步）

## 编辑器优化
- [x] `TranscriptRow` 两行布局
- [x] 说话人标签截断 10 字符
- [x] 不同说话人统一颜色分配（`colorForSpeaker` 按顺序）
- [x] 发言统计含所有参会人（0 句也显示）
- [x] 说话人匹配只显示未绑定临时说话人
- [x] 发言统计支持重命名参会人
- [x] 鼠标悬停行高亮（`.onHover`）
- [x] 合并按钮右对齐
- [x] 文本编辑器隐藏滚动条
- [x] 文本左对齐说话人位置
