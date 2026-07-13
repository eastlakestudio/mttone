import Foundation
import AVFoundation
import FluidAudio

struct DiarizedSegment {
    let speakerId: String
    let startTime: Double
    let endTime: Double
}

actor DiarizationService {
    static let shared = DiarizationService()
    
    private var manager: OfflineDiarizerManager?
    
    private func getManager() async throws -> OfflineDiarizerManager {
        if let manager = manager {
            return manager
        }
        print("[DiarizationService] 初始化 FluidAudio 离线分离器并检查模型...")
        
        // clusteringThreshold 是一个相似度阈值（不是距离）。
        // 数值越高越宽松合并，数值越低越严格分离。0.7 ~ 0.8 是比较好的平衡点。
        // 之前 0.45 过于宽松导致多人声音被合并成一个。
        let config = OfflineDiarizerConfig(clusteringThreshold: 0.75)
        let newManager = OfflineDiarizerManager(config: config)
        try await newManager.prepareModels()
        self.manager = newManager
        return newManager
    }

    /// 使用 FluidAudio 本地模型提取声纹特征并进行聚类
    func diarize(audioURL: URL) async throws -> [DiarizedSegment] {
        print("[DiarizationService] 开始端侧声纹分离...")
        
        let manager = try await getManager()
        
        print("[DiarizationService] 正在重采样音频文件...")
        // FluidAudio 需要特定的采样率
        let samples = try AudioConverter().resampleAudioFile(path: audioURL.path)
        
        print("[DiarizationService] 正在执行模型推理...")
        let result = try await manager.process(audio: samples)
        
        let segments = result.segments.map { segment in
            DiarizedSegment(
                speakerId: "Speaker_\(segment.speakerId)", 
                startTime: Double(segment.startTimeSeconds), 
                endTime: Double(segment.endTimeSeconds)
            )
        }
        
        let uniqueSpeakers = Set(segments.map(\.speakerId)).sorted()
        let msg = "声纹聚类完毕: \(segments.count) 区间 / \(uniqueSpeakers.count) 不同说话人 (\(uniqueSpeakers.joined(separator: ", ")))"
        let segSamples = segments.prefix(8).map { "\($0.speakerId)[\(Int($0.startTime))-\(Int($0.endTime))s]" }.joined(separator: ", ")
        let detailMsg = "\(msg), 样例: \(segSamples)"
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss.SSS"
        let line = "\(df.string(from: Date())) [Diar] \(detailMsg)\n"
        if let d = line.data(using: String.Encoding.utf8), let h = FileHandle(forWritingAtPath: "/tmp/mttone_diag.log") {
            h.seekToEndOfFile(); h.write(d); h.closeFile()
        } else { try? line.write(toFile: "/tmp/mttone_diag.log", atomically: true, encoding: String.Encoding.utf8) }
        return segments
    }
}
