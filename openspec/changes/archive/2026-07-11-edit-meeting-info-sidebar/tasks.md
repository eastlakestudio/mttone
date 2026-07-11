# 开发任务列表

- [ ] 数据库表结构升级与模型扩展
  - [ ] 修改 `Models/Models.swift` 为 `Meeting` 增加 `attendees` 属性，支持可选 String 格式
  - [ ] 修改 `DatabaseManager.swift`，在数据库初始化时执行 `ALTER TABLE meetings ADD COLUMN attendees TEXT` 的安全补丁
  - [ ] 修改 `DatabaseManager.swift` 中与 `meetings` 查询和插入相关的所有 SQL 语句，读取和绑定 `attendees` 列
- [ ] 编写 ViewModel 增量更新逻辑
  - [ ] 在 `DatabaseManager` 中实现 `updateMeetingInfo` 数据库持久化修改方法
  - [ ] 在 `RecordingViewModel` 中编写 `updateMeetingMetadata` 供 UI 直接调用，刷新本地 currentMeeting 并自动落库
- [ ] 构建右侧折叠 Sidebar 检查器 (Inspector)
  - [ ] 在 `ReviewingView` 的 Toolbar 右上角添加侧边栏控制 Toggle 按钮
  - [ ] 在 `ReviewingView` 主体结构嵌套 `HStack`，左侧为转写主窗口，右侧为 240px 的 `VStack` Sidebar 面板
  - [ ] 编写 Sidebar 内的“主题”、“时间”、“地点”、“参会人标签组”输入交互，实现失焦/改变自动调用 ViewModel 保存
- [ ] 打通转写气泡说话人快捷绑定
  - [ ] 为 `TranscriptBubble` 提供 `attendees: [String]` 入参列表
  - [ ] 在气泡说话人输入框旁提供 Menu，允许点击一键选择已有的参会人名字，触发重命名绑定
- [ ] 整体编译运行与功能联调测试
