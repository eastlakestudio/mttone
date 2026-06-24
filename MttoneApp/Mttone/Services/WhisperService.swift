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
        // WhisperKit 直接支持输入本地音频文件路径
        let results = try await pipe.transcribe(audioPath: audioURL.path)
        
        var parsedSegments: [TranscriptSegment] = []
        
        if let result = results.first {
            for (index, segment) in result.segments.enumerated() {
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
}
