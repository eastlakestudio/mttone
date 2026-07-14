import Foundation
import WhisperKit

actor WhisperService {
    static let shared = WhisperService()
    
    private var pipe: WhisperKit?
    private(set) var isReady = false
    private(set) var isLoading = false
    
    private var defaultModelPath: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml").path
    }

    /// 初始化并预加载模型
    func initialize() async throws {
        if isReady && pipe != nil { return }
        isLoading = true
        defer { isLoading = false }
        
        let log = { (msg: String) in try? "[Whisper] \(msg)\n".data(using: .utf8).flatMap {
            let h = FileHandle(forWritingAtPath: "/tmp/mttone_diag.log"); h?.seekToEndOfFile(); h?.write($0); h?.closeFile()
        } }
        
        let settings = SettingsManager.shared
        var modelID = settings.selectedVoice.replacingOccurrences(of: "openai/", with: "openai_")
        if settings.selectedVoice == "openai/whisper-large-v3-turbo" {
            modelID = "openai_whisper-large-v3_turbo"
        }
        let basePath = settings.modelPath
        if basePath.isEmpty {
            log("错误: 模型缓存路径未设置，请在设置中选择路径并下载模型。")
            throw NSError(domain: "WhisperService", code: 400, userInfo: [NSLocalizedDescriptionKey: "模型未下载，请前往系统设置选择路径并进行下载。"])
        }
        let endpoint = settings.useChinaMirror ? "https://hf-mirror.com" : "https://huggingface.co"
        
        log("开始加载/下载模型: \(modelID) (缓存路径: \(basePath), 源: \(endpoint))...")
        
        let config = WhisperKitConfig(
            model: modelID,
            downloadBase: URL(fileURLWithPath: basePath),
            modelEndpoint: endpoint
        )
        self.pipe = try await WhisperKit(config)
        self.isReady = true
        log("模型加载完成!")
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
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "模型加载失败，请检查网络后重试"])
        }

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
                DispatchQueue.main.async { onSegments(mapped) }
            }
        }
        
        let log = { (msg: String) in
            let df = DateFormatter(); df.dateFormat = "HH:mm:ss.SSS"
            let line = "\(df.string(from: Date())) [Whisper] \(msg)\n"
            if let d = line.data(using: .utf8), let h = FileHandle(forWritingAtPath: "/tmp/mttone_diag.log") {
                h.seekToEndOfFile(); h.write(d); h.closeFile()
            } else { try? line.write(toFile: "/tmp/mttone_diag.log", atomically: true, encoding: .utf8) }
        }
        log("开始转写: \(audioURL.lastPathComponent), 模型=large-v3, lang=\(language), temp=0.0")

        // 设置段发现回调，并统计回调次数
        var callbackCount = 0
        if let onSegments = onSegments {
            pipe.segmentDiscoveryCallback = { whisperSegments in
                callbackCount += 1
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
                DispatchQueue.global().async {
                    let sample = mapped.prefix(2).map { "[\(Int($0.startTime))s] \($0.text.prefix(30))" }.joined(separator: " | ")
                    log("callback#\(callbackCount): \(mapped.count)段, 样例: \(sample)")
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
            log("转写完成: \(result.segments.count) 段, callback共触发\(callbackCount)次")
            // 打印转写文本样例
            let samples = result.segments.prefix(5).map { "[\(Int($0.start))s] \($0.text.prefix(40))" }.joined(separator: " | ")
            log("文本样例: \(samples)")
            for (index, segment) in result.segments.enumerated() {
                let text = segment.text
                let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
                    text: segment.text.toSimplifiedChinese(),
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
    func transcribeLive(audioArray: [Float], language: String = "zh") async throws -> String {
        guard let pipe = pipe else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "模型尚未加载完成"])
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
        
        // 过滤幻觉
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
