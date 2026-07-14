## ADDED Requirements

### Requirement: Global Speaker List in Meeting Review
在会议回顾（管理）界面中，右侧属性面板必须提供一个“当前会议声纹人统计”模块，展示当前会议中检测到的所有说话人（Speaker）及其发言句数、总时长。

#### Scenario: Visualizing speaker statistics
- **WHEN** 用户在会议回顾界面打开属性面板
- **THEN** 系统展示该会议中所有出现的说话人列表，并显示每个人的总发言句数和总发言时长

### Requirement: Multi-level Speaker Rename Dropdown
转写气泡的说话人标签必须为一个直观的可点击按钮。点击后，应提供一个下拉菜单（Popover/Menu），其中包含：
1. 参会人列表（可快速绑定）
2. 全局声纹人列表（可跨会议关联）
3. “新建声纹人并绑定”的输入选项
用户选择或修改后，该会议中所有相同识别 ID 的发言人标签必须同步自动更新。

#### Scenario: Renaming speaker propagates globally in the meeting
- **WHEN** 用户在某个气泡上将 "Speaker_S1" 修改为 "lmh"
- **THEN** 界面中所有原为 "Speaker_S1" 的气泡均自动将说话人更新为 "lmh"，且底层数据关联到全局声纹人 "lmh"
