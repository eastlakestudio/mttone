## 1. 模型参数调整

- [x] 1.1 `compressionRatioThreshold`: 2.4 → 1.5（`WhisperService.swift` 第 106 行）
- [x] 1.2 `noSpeechThreshold`: 0.6 → 0.75（`WhisperService.swift` 第 107 行）

## 2. 验证

- [x] 2.1 编译通过
- [ ] 2.2 用已知产生乱码的音频测试，确认乱码消失
- [ ] 2.3 用正常录音测试，确认无误杀
