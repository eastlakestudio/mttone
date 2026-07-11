## 1. 修复子组件状态更新不同步 (SwiftUI State Bug)

- [ ] 1.1 在 `TranscriptBubble` 中，为 `editedSpeaker` 和 `editedText` 添加 `.onChange(of: segment.speakerLabel)` 和 `.onChange(of: segment.text)` 监听，确保父级重命名或拆分能立刻反应在气泡上。

## 2. 气泡说话人选择与绑定下拉菜单改造

- [ ] 2.1 改造 `TranscriptBubble` 中的说话人标签为明显的按钮，并添加 `chevron.down` 视觉指示。
- [ ] 2.2 在下拉菜单中合并展示：会议参会人列表、全局声纹人名册，允许用户直接点选绑定。
- [ ] 2.3 菜单中整合文本输入框，用户直接输入新名字可对当前说话人发起全局重命名（调用 `updateSpeakerLabel`，自动创建并关联全局 `Contact` 记录）。

## 3. 会议回顾界面右侧面板增加声纹发言统计

- [ ] 3.1 扩展 `ReviewingView.swift` 的右侧属性检查器（`inspectorSidebar`），在底部新增“声纹发言统计”分区。
- [ ] 3.2 根据当前会议已有的段落，按 Speaker 聚合统计发言句数、发言总时长，并进行排序列表展示。
- [ ] 3.3 支持点击统计列表中的声纹人，使左侧转写列表过滤或高亮显示该声纹人的发言。

## 4. 显式拆分文本与分配新说话人

- [ ] 4.1 在 `TranscriptBubble` 工具栏添加显式的剪刀（拆分）按钮。
- [ ] 4.2 点击剪刀按钮展示 Popover，在其中展示当前文本，并允许用户编辑文本以指定回车切分点。
- [ ] 4.3 拆分 Popover 内提供第二部分的新说话人（New Speaker）选择器。
- [ ] 4.4 升级 `RecordingViewModel.splitSegment(id:text1:text2:newSpeakerForPart2:)` 接口，支持为第二段指定新的 Speaker。
- [ ] 4.5 连接 UI 确认按钮，调用升级后的拆分方法并自动刷新 Reviewing 视图，验证拆分并分配成功。
