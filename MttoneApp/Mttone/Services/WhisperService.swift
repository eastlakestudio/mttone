import Foundation
import WhisperKit

actor WhisperService {
    static let shared = WhisperService()
    
    private var pipe: WhisperKit?
    private(set) var isReady = false
    private(set) var isLoading = false
    
    private var defaultModelPath: String { SettingsManager.shared.defaultModelPath }

    /// 初始化并预加载模型（仅从本地磁盘加载，不访问网络）
    /// 模型必须先通过「系统配置」页面下载，否则抛出错误引导用户下载
    func initialize() async throws {
        if isReady && pipe != nil { return }
        isLoading = true
        defer { isLoading = false }
        
        let settings = SettingsManager.shared
        var modelID = settings.selectedVoice.replacingOccurrences(of: "openai/", with: "openai_")
        if settings.selectedVoice == "openai/whisper-large-v3-turbo" {
            modelID = "openai_whisper-large-v3_turbo"
        }
        let basePath = settings.modelPath
        if basePath.isEmpty {
            throw NSError(domain: "WhisperService", code: 400,
                userInfo: [NSLocalizedDescriptionKey: loc("model_not_downloaded_settings")])
        }
        
        // 计算模型本地文件夹（与 SettingsView 下载目录结构一致）
        let primaryPath = "\(basePath)/models/argmaxinc/whisperkit-coreml/\(modelID)"
        let altPath = "\(basePath)/\(modelID)"
        
        func hasModel(at path: String) -> Bool {
            let folder = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else { return false }
            let marker = folder.appendingPathComponent(".download_complete")
            return FileManager.default.fileExists(atPath: marker.path)
        }
        
        let localPath: String? = hasModel(at: primaryPath) ? primaryPath : (hasModel(at: altPath) ? altPath : nil)
        
        guard let modelPath = localPath else {
            throw NSError(domain: "WhisperService", code: 404,
                userInfo: [NSLocalizedDescriptionKey: loc("model_not_downloaded_settings")])
        }
        
        let config = WhisperKitConfig(modelFolder: modelPath)
        self.pipe = try await WhisperKit(config)
        self.isReady = true
        AppLog.info("模型加载成功: \(modelPath)")
    }
    
    /// 重置服务，以备重新载入新模型
    func reset() {
        self.pipe = nil
        self.isReady = false
    }
    
    /// 对保存的录音文件进行高精度离线转写
    func transcribe(audioURL: URL, meetingId: String, language: String = "zh", onSegments: (([TranscriptSegment]) -> Void)? = nil) async throws -> [TranscriptSegment] {
        // 强制确保模型已加载
        try await initialize()
        guard let pipe = pipe else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: loc("model_load_failed")])
        }

        AppLog.info("离线转写开始: audio=\(audioURL.lastPathComponent) lang=\(language)")

        // 设置段发现回调：转写过程中持续输出中间结果
        if let onSegments = onSegments {
            pipe.segmentDiscoveryCallback = { whisperSegments in
                let mapped = whisperSegments.map { seg in
                    TranscriptSegment(
                        id: "\(meetingId)_\(seg.id)",
                        startTime: Double(seg.start),
                        endTime: Double(seg.end),
                        text: seg.text.toSimplifiedChinese(),
                        speakerLabel: "Speaker_1",
                        isFinal: true
                    )
                }
                onSegments(mapped)
            }
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: 0,
            sampleLength: 224,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            compressionRatioThreshold: 2.4,
            noSpeechThreshold: 0.6
        )

        var parsedSegments: [TranscriptSegment] = []

        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)

        if let result = results.first {
            for (index, segment) in result.segments.enumerated() {
                let text = segment.text
                let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                guard !trimmedText.isEmpty else {
                    continue
                }
                
                // 过滤常见的 Whisper 幻觉文本（模型行为过滤，非 UI 文本，无需国际化）
                let lower = trimmedText.lowercased()
                let hallucinations = ["字幕", "j chong", "amara.org", "感谢观看", "请不吝赐教", "不发音", "无声"]
                if hallucinations.contains(where: { lower.contains($0) }) {
                    continue
                }
                
                let parsedSegment = TranscriptSegment(
                    id: "\(meetingId)_\(segment.id)",
                    startTime: Double(segment.start),
                    endTime: Double(segment.end),
                    text: segment.text.toSimplifiedChinese(),
                    speakerLabel: "Speaker_1", // Whisper 不支持声纹分离，默认统一标签
                    isFinal: true
                )
                parsedSegments.append(parsedSegment)
            }
        }
        
        AppLog.info("离线转写完成: \(parsedSegments.count) 段")
        return parsedSegments
    }
    
    /// 用于实时录音时的快速短句推理
    /// 传入音频缓冲区数组，返回转写出的连续文本
    func transcribeLive(audioArray: [Float], language: String = "zh") async throws -> String {
        guard let pipe = pipe else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: loc("model_not_loaded")])
        }
        
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            skipSpecialTokens: true,
            withoutTimestamps: false
        )
        
        // 使用 WhisperKit 的纯数组转写接口
        let results = try await pipe.transcribe(audioArray: audioArray, decodeOptions: options)
        
        guard let result = results.first else {
            return ""
        }
        
        // 直接使用 result.text，避免 segments 可能为空的情况
        let fullText = result.text.trimmingCharacters(in: .whitespacesAndNewlines).toSimplifiedChinese()
        
        // 过滤幻觉（模型行为过滤，非 UI 文本，无需国际化）
        let lower = fullText.lowercased()
        let hallucinations = ["字幕", "j chong", "amara.org", "感谢观看", "请不吝赐教", "不发音", "无声"]
        if hallucinations.contains(where: { lower.contains($0) }) {
            return ""
        }
        
        return fullText
    }
}

extension String {
    func toSimplifiedChinese() -> String {
        let mutable = NSMutableString(string: self)
        CFStringTransform(mutable, nil, "Hant-Hans" as CFString, false)
        return mutable as String
    }
}
