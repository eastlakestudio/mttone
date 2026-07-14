# Proposal: Apple 液态玻璃 UI 样式 + 首页工具栏

## Why
- 首页工具栏缺少「人员与声纹」入口
- 整体 UI 需要统一现代化风格

## What Changes

### 首页工具栏
- 添加「人员与声纹」NavigationLink 按钮

### 液态玻璃效果
Apple macOS 14+ 的液态玻璃效果通过以下 SwiftUI 修饰符实现：
- `.background(.ultraThinMaterial)` — 半透明毛玻璃（已有）
- `.background(.regularMaterial)` — 更强的模糊效果
- `.background(.thinMaterial)` — 较轻的模糊
- 深色/浅色模式自动适配

**当前应用已大量使用 `ultraThinMaterial` 和 `regularMaterial`**，这是 macOS 14+ 上最接近液态玻璃的效果。在 macOS 15+ 可通过 `.glassBackgroundEffect()` 获得真正的液态玻璃。

### 优化点
- 统一侧边栏背景为 `.regularMaterial`
- 转录列表卡片增加微边框和阴影
- 发言人标签使用 vibrant 颜色
- 会议列表增加间距和分隔线

### 涉及文件
- `MeetingListView.swift` — 首页列表 + 工具栏
- `LeftSidebar.swift` — 左侧导航栏
- `ReviewingView.swift` — 会议回顾主界面
- `UnifiedTranscriptEditor.swift` — 转录行样式
- `MeetingInfoSidebar.swift` — 右侧属性面板
