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
        
        // 默认 clusteringThreshold 是 0.6。
        // 如果把两个人的声音合并了，说明阈值太宽松了。降低阈值（如 0.45）可以更严格地把不同特征判定为不同的人。
        let config = OfflineDiarizerConfig(clusteringThreshold: 0.45)
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
        
        print("[DiarizationService] 声纹聚类推理完毕，共分离出 \(segments.count) 个发音区间")
        return segments
    }
}
