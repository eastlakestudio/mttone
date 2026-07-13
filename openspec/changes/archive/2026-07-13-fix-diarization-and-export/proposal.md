# Proposal: 修复声纹分离 + 会议记录导出

## Why
- 多人会议声音被合并成一个说话人
- 需要导出会议记录功能

## What
- DiarizationService: clusteringThreshold 0.45→0.75（阈值方向修正）
- 人员管理属性面板支持编辑保存
- 发言统计新增"分配到参会人"菜单
- ReviewingView 新增导出会议记录(.txt)
