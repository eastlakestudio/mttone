# 技术设计：非模态检查器与数据库模式迁移

## 1. 数据库模式迁移 (Database Migration)
- 在 `DatabaseManager.swift` 中：
  ```sql
  ALTER TABLE meetings ADD COLUMN attendees TEXT;
  ```
  在数据库 `createTables()` 的执行流中进行尝试执行，由于 SQLite 缺少 `ADD COLUMN IF NOT EXISTS`，我们通过静默捕获该执行结果或在表初始化后显式通过 `PRAGMA table_info(meetings)` 检查是否存在 `attendees` 列来按需添加。

## 2. 界面视图树结构 (View Hierarchy)
```
ReviewingView (VStack)
├── NavigationStack Toolbar (右上角 [|||] 侧边栏折叠 Toggle)
└── HStack (主工作区)
    ├── VStack (左侧核心工作区 - 自适应拉满)
    │   ├── playbackControlPanel (播放控制)
    │   └── ScrollView (转译文本流)
    │       └── ForEach(transcriptSegments)
    │           └── TranscriptBubble (气泡)
    │               └── Menu (带下拉箭头的参会人快捷绑定)
    └── VStack (右侧 Inspector Sidebar - 固定 240px 宽 - 条件展示)
        ├── 标题 ("会议属性检查器")
        ├── 会议主题 (VStack -> TextField)
        ├── 开始时间 (VStack -> Button + DatePicker Popover)
        ├── 会议地点 (VStack -> TextField)
        └── 参会人员 (VStack -> FlowLayout FlowTags + TextField)
```

## 3. 双向数据流与自动存盘
- 在 `RecordingViewModel` 中定义 `updateMeetingMetadata(title:location:createdAt:attendees:)`。
- Sidebar 内的各组件使用 `@State` 缓冲用户输入，当 TextField 触发 `.onChange` / `.onSubmit` 或 `.onEditingChanged` (或 `DatePicker` 值改变) 时，异步调用 ViewModel 进行存盘。
