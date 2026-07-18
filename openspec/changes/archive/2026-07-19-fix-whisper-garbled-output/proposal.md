## Why

Whisper 模型在静音段/低信噪比区域产出字符级乱码（如"掐掐掐扫掐掐..."），现有 `compressionRatioThreshold: 2.4` 偏宽松，不足以拦截此类循环退化输出。

## What Changes

- `compressionRatioThreshold`: 2.4 → 1.5（激进过滤循环重复）
- `noSpeechThreshold`: 0.6 → 0.75（减少静音段进入 decoder，从源头降低幻觉）
- 仅模型参数层面调整，不加任何应用层过滤逻辑

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
<!-- None — parameter tuning only, no API/spec change -->

## Impact

- `WhisperService.swift`：`transcribeOffline` 的 `DecodingOptions` 两行参数修改
