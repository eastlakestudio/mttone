## 1. 数据库与数据模型升级

- [x] 1.1 扩展 `DatabaseManager.swift`，增加根据 `contact_id` 查询跨会议 `speech_clips` 的聚合接口。
- [x] 1.2 在 `SpeechClip` 及数据库处理逻辑中，确保 `contact_id` 能完整支持跨会议检索和更新。

## 2. 全局联系人与声纹管理

- [x] 2.1 创建 `GlobalSpeakerListView.swift` 页面，展示全局所有的联系人名册及发言统计。
- [x] 2.2 创建 `SpeakerDetailView.swift` 页面，按时间序展示该人物在各会议中的具体发言文本。
- [x] 2.3 在 APP 主界面（如主导航栏或侧边栏）添加入口链接至该全局管理模块。

## 3. 气泡音频裁剪回放

- [x] 3.1 在 `TranscriptBubble` 组件中增加音频回放播放/暂停按钮。
- [x] 3.2 借助 `AVFoundation` 或系统播放器，编写 `RecordingViewModel` 中的逻辑，使其仅在对应片段的 `start_time` 与 `end_time` 间播放声音。

## 4. 转写气泡的手动切分

- [x] 4.1 在 `TranscriptBubble` 中拦截回车换行事件（可借助包装的原生 `NSTextView`）。
- [x] 4.2 编写拆分算法：通过字符比例估算，将原片段的文字及起止时间戳一分为二，生成两条新的 `SpeechClip` 对象。
- [x] 4.3 在 `DatabaseManager.swift` 中编写 `splitSpeechClip` 方法，利用数据库事务删除旧记录并插入两条新记录，刷新列表。

## 5. 整体联调与测试

- [x] 5.1 在右侧属性栏重命名或绑定时，验证跨会议下 `contact_id` 外键正确挂载。
- [x] 5.2 运行端到端测试，包括跨会议浏览、单会议切分、播放进度校验。
