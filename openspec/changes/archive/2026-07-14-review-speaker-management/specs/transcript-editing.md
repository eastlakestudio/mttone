## ADDED Requirements

### Requirement: Split Transcript Bubble with Reassignment
转写气泡必须提供一个显式的“拆分”入口按钮。点击后：
1. 弹出拆分操作框，展示当前文本
2. 用户可选择拆分位置，并为拆分出来的第二段文本重新选择/分配一个新的声纹人
3. 确定拆分后，系统将该片段在时间轴上切分为两段，并将对应的两个新片段分配给各自指定的声纹人，同时更新数据库

#### Scenario: User splits a bubble and assigns to a different speaker
- **WHEN** 用户点击气泡上的“拆分”按钮，并在文字中间插入拆分，为第二段指定说话人 "lmh"
- **THEN** 原片段被拆分为两个气泡，第二段气泡的说话人显示为 "lmh"
