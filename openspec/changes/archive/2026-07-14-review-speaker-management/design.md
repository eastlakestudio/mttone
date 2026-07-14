## Context

当前的转写回顾界面（`ReviewingView.swift`）和转写气泡（`TranscriptBubble`）在声纹管理上有以下痛点：
1. 声纹修改无全局实时同步：修改某段的说话人姓名时，由于 `TranscriptBubble` 使用了 `@State` 存储 `editedSpeaker` 和 `editedText`，SwiftUI 父组件状态更新无法自动推送到子组件，导致“修改一个，其他未同步改变”的感知。
2. 缺乏声纹字典可视化统计：在回顾页面中，无法快速查看当前会议有哪些声纹人，以及他们各自说了哪些话。
3. 拆分逻辑隐蔽且单一：通过键盘回车直接拆分较为隐蔽，且不支持在拆分时直接将第二段分配给其他声纹人。

## Goals / Non-Goals

**Goals:**
- 在 `ReviewingView` 的右侧属性栏添加“声纹统计”面板，展示当前会议所有说话人及其发言统计，并支持点击过滤/高亮。
- 修复 `TranscriptBubble` 中的 `@State` 响应 bug，实现一处修改，该会议中所有相同 Speaker 自动全局实时同步更改。
- 优化气泡上的说话人修改界面：点击说话人名称弹出悬浮菜单（Popover/Menu），整合参会人列表、全局声纹人名册以及快捷输入。
- 在气泡工具栏添加显式的“拆分并分配”按钮，支持通过弹窗选择拆分点，并直接指定第二段的声纹人。

**Non-Goals:**
- 音频物理文件的波形级别精确切割（依然采用基于字符比例的时间戳估算）。

## Decisions

### 1. 修复子组件状态更新不同步 (SwiftUI State Bug)
在 `TranscriptBubble` 中，为 `@State private var editedSpeaker` 和 `@State private var editedText` 增加 `.onChange(of: segment.speakerLabel)` 和 `.onChange(of: segment.text)`。
- **Why**: 这样当父组件在内存中批量修改 `speakerLabel` 后，所有对应的子气泡都会同步更新他们本地的编辑状态，解决用户看到的“未自动修改”的问题。

### 2. 气泡说话人菜单改造
将 `TranscriptBubble` 的说话人文本改为 `Button`，点击后展示 `Menu`，菜单包含：
- **参会人**: 会议属性中设置的 `attendees`。
- **声纹字典**: 全局数据库中的 `contacts`。
- **自定义/重命名**: 提供一个文本输入弹窗，允许输入新名字，从而触发 `updateSpeakerLabel` 机制（将所有该说话人重命名，若未在全局注册则在 DB 中自动创建联系人并挂载 `contactId`）。

### 3. 可视化拆分工具（剪刀按钮）
在 `TranscriptBubble` 增加剪刀图标按钮，点击后弹出 Popover。
Popover 内提供：
- 完整的当前文本展示（可在其中选择拆分点）。
- 分割点选择输入框或操作指南。
- 拆分后第二部分的说话人选择器。
- 点击“确定拆分”，调用 ViewModel 的 `splitSegment(id:text1:text2:newSpeakerForPart2:)` 进行拆分并持久化。
