# Proposal: 全局人员与声纹管理 + 编辑器优化

## Why
- 声纹字典（GlobalSpeakerListView）和人员管理（PersonnelManagementView）功能重叠，应统一
- 参会人输入应支持搜索全局人员库而非纯自由文本
- 新建人员需填写人名/角色/组织完整属性
- 转写编辑器需改进布局和交互

## What Changes

### 全局人员管理合并
- 删除 `GlobalSpeakerListView` 和 `SpeakerDetailView`
- `PersonnelManagementView` 升级为双列布局：
  - 左列：人员列表 + 选中人属性（姓名/角色/组织）
  - 右列：按会议分组的发言记录（JOIN 查询）
- 所有引用处统一指向 `PersonnelManagementView`

### Contact 模型扩展
- 新增 `role` / `company` 字段
- 新增 `displayName` 计算属性
- DB 自动迁移（ALTER TABLE）

### 参会人选择改进
- 搜索框实时筛选全局人员（按姓名/角色/公司匹配）
- 回车/点击添加
- 新建按钮弹出 `NewContactSheet`（人名/角色/组织）
- 新说话人自动同步为参会人

### 编辑器优化
- 两行布局：第一行播放+时间+说话人+时长+合并，第二行文本
- 说话人名称截断 10 字符
- 不同说话人统一分配颜色
- 发言统计含所有参会人，可重命名
- 说话人匹配只显示未绑定临时说话人
