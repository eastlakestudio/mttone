## Context

"掐掐掐扫掐掐..."类乱码是 Whisper 自注意力循环退化。模型层防线 `compressionRatioThreshold` 目前 2.4，不足以拦截。

## Decisions

### compressionRatioThreshold: 2.4 → 1.5

**选择**：直接降到 1.5，不留中间值。

**理由**：
- 乱码文本压缩比通常 < 1.3（极高重复），正常中文文本 > 2.0
- 1.5 与正常文本有足够安全边际（0.5+ 差距）
- 叠加 `noSpeechThreshold` 提高，误杀风险极低

### noSpeechThreshold: 0.6 → 0.75

**选择**：提高静音判定敏感度。

**理由**：
- 乱码根因是模型在低信噪比段强行输出 token
- 0.75 让更多静音/噪声段直接被跳过，不进入 decoder
- 0.6 → 0.75 的提升仍安全，正常语音段 logprob 远高于此

## Risks

- [误杀极短语音] → 叠加 `compressionRatioThreshold: 1.5` + `noSpeechThreshold: 0.75`，正常语音 logprob > 0.9，压缩比 > 2.0，不会误杀
- [如果还漏] → 下次再调，不加应用层代码
