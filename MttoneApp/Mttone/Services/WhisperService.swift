import Foundation
import WhisperKit

actor WhisperService {
    static let shared = WhisperService()
    
    private var pipe: WhisperKit?
    private(set) var isReady = false
    private(set) var isLoading = false
    
    /// 初始化并预加载模型（例如 openai_whisper-tiny 或 openai_whisper-base）
    func initialize() async throws {
        guard !isReady && !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        print("[WhisperService] 开始加载模型...")
        // 这里默认加载轻量级的 base 模型，初次运行会自动从 HuggingFace 下载
        self.pipe = try await WhisperKit(model: "openai_whisper-base")
        self.isReady = true
        print("[WhisperService] 模型加载完成！")
    }
    
    /// 对保存的录音文件进行高精度离线转写
    func transcribe(audioURL: URL, meetingId: String) async throws -> [TranscriptSegment] {
        guard let pipe = pipe else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "模型尚未加载完成"])
        }
        
        print("[WhisperService] 开始对 \(audioURL.path) 进行离线高精度转写...")
        
        // 配置解码选项：强制中文、去掉特殊 token、保留时间戳
        let options = DecodingOptions(
            task: .transcribe,
            language: "zh",
            skipSpecialTokens: true,
            withoutTimestamps: false
        )
        
        // WhisperKit 直接支持输入本地音频文件路径
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)
        
        var parsedSegments: [TranscriptSegment] = []
        
        if let result = results.first {
            for (index, segment) in result.segments.enumerated() {
                let trimmedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else {
                    continue
                }
                
                // 过滤常见的 Whisper 幻觉文本（中文训练集中常出现的字幕组或静音噪音产物）
                let lower = trimmedText.lowercased()
                let hallucinations = ["字幕", "j chong", "amara.org", "感谢观看", "请不吝赐教", "不发音", "无声"]
                if hallucinations.contains(where: { lower.contains($0) }) {
                    continue
                }
                
                let parsedSegment = TranscriptSegment(
                    id: "\(meetingId)_whisper_\(index)",
                    startTime: Double(segment.start),
                    endTime: Double(segment.end),
                    text: segment.text,
                    speakerLabel: "Speaker_1", // Whisper 不支持声纹分离，默认统一标签
                    isFinal: true
                )
                parsedSegments.append(parsedSegment)
            }
        }
        
        print("[WhisperService] 转写完成，共生成 \(parsedSegments.count) 段")
        return parsedSegments
    }
    
    /// 用于实时录音时的快速短句推理
    /// 传入音频缓冲区数组，返回转写出的连续文本
    func transcribeLive(audioArray: [Float]) async throws -> String {
        guard let pipe = pipe else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "模型尚未加载完成"])
        }
        
        // 极速模式：不带时间戳，关闭冗余输出
        let options = DecodingOptions(
            task: .transcribe,
            language: "zh",
            skipSpecialTokens: true,
            withoutTimestamps: false // 保守起见，保持 false，某些模型在 true 下可能不吐字
        )
        
        // 使用 WhisperKit 的纯数组转写接口
        let results = try await pipe.transcribe(audioArray: audioArray, decodeOptions: options)
        
        guard let result = results.first else {
            return ""
        }
        
        // 直接使用 result.text，避免 segments 可能为空的情况
        let fullText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 过滤幻觉
        let lower = fullText.lowercased()
        let hallucinations = ["字幕", "j chong", "amara.org", "感谢观看", "请不吝赐教", "不发音", "无声"]
        if hallucinations.contains(where: { lower.contains($0) }) {
            return ""
        }
        
        return fullText
    }
}
