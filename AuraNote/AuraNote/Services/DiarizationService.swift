import Foundation
import AVFoundation
import FluidAudio

struct DiarizedSegment {
    let speakerId: String
    let startTime: Double
    let endTime: Double
}

struct DiarizationOutput {
    let segments: [DiarizedSegment]
    /// FBANK 管线产出的声纹（256 维），用于离线匹配
    let speakerEmbeddings: [String: [Float]]
    /// 原始波形管线产出的声纹（256 维），用于实时匹配（与 extractEmbedding 同模型）
    let rawSpeakerEmbeddings: [String: [Float]]
}

actor DiarizationService {
    static let shared = DiarizationService()
    
    private var manager: OfflineDiarizerManager?
    /// 轻量 DiarizerManager：用于单片段声纹提取，仅 WeSpeaker 模型
    /// 存储的声纹也是原始 256 维 WeSpeaker 嵌入，无需 PLDA 变换
    private var lightManager: DiarizerManager?
    
    private func getManager() async throws -> OfflineDiarizerManager {
        if let manager = manager {
            return manager
        }
        let config = OfflineDiarizerConfig(clusteringThreshold: SettingsManager.shared.clusteringThreshold)
        let newManager = OfflineDiarizerManager(config: config)
        try await newManager.prepareModels()
        self.manager = newManager
        return newManager
    }
    
    /// 获取轻量 DiarizerManager（仅 WeSpeaker 模型，不加载 PLDA）
    private func getLightManager() async throws -> DiarizerManager {
        if let lm = lightManager { return lm }
        let models = try await DiarizerModels.download()
        let lm = DiarizerManager()
        lm.initialize(models: models)
        self.lightManager = lm
        return lm
    }

    func diarize(audioURL: URL) async throws -> [DiarizedSegment] {
        let output = try await diarizeWithEmbeddings(audioURL: audioURL)
        return output.segments
    }

    func diarizeWithEmbeddings(audioURL: URL) async throws -> DiarizationOutput {
        AppLog.info("Voiceprint diarization engine started: audio=\(audioURL.lastPathComponent)")
        let manager = try await getManager()
        let samples = try AudioConverter().resampleAudioFile(path: audioURL.path)
        AppLog.info("Audio resampling complete: \(samples.count) samples")
        let result = try await manager.process(audio: samples)
        
        let segments = result.segments.map { segment in
            DiarizedSegment(
                speakerId: "Speaker_\(segment.speakerId)",
                startTime: Double(segment.startTimeSeconds),
                endTime: Double(segment.endTimeSeconds)
            )
        }
        
        // 重映射 speakerDatabase 的 key: S1→Speaker_S1，与 segments 的 speakerId 一致
        let rawDB = result.speakerDatabase ?? [:]
        var remappedDB: [String: [Float]] = [:]
        for (key, emb) in rawDB {
            remappedDB["Speaker_\(key)"] = emb
        }
        
        let uniqueSpeakers = Set(segments.map(\.speakerId)).sorted()
        
        // 用实时同款模型（原始波形 WeSpeaker）重新提取每个说话人的声纹，
        // 存入联系人库后可与实时片段匹配对齐向量空间
        var rawEmbeddings: [String: [Float]] = [:]
        if !uniqueSpeakers.isEmpty {
            let lm = try? await getLightManager()
            for speakerId in uniqueSpeakers {
                // 聚合该说话人所有区间的音频
                var speakerSamples: [Float] = []
                for seg in segments where seg.speakerId == speakerId {
                    let startIdx = Int(Double(seg.startTime) * 16000.0)
                    let endIdx = min(Int(Double(seg.endTime) * 16000.0), samples.count)
                    if startIdx < endIdx {
                        speakerSamples.append(contentsOf: samples[startIdx..<endIdx])
                    }
                }
                if !speakerSamples.isEmpty, let lm = lm {
                    if let emb = try? lm.extractSpeakerEmbedding(from: speakerSamples) {
                        rawEmbeddings[speakerId] = emb
                    }
                }
            }
            AppLog.info("Raw waveform voiceprint extraction complete: \(rawEmbeddings.count) speakers")
        }
        
        return DiarizationOutput(segments: segments, speakerEmbeddings: remappedDB, rawSpeakerEmbeddings: rawEmbeddings)
    }

    /// 从原始音频采样中提取说话人声纹向量（用于实时片段级说话人匹配）
    /// 返回 256 维原始 WeSpeaker 嵌入，与离线管线存储的声纹在同一向量空间
    /// - Parameter audioSamples: 16kHz 单声道 Float 采样
    /// - Returns: 256 维声纹向量，若提取失败返回 nil
    func extractEmbedding(from audioSamples: [Float]) async -> [Float]? {
        guard !audioSamples.isEmpty else { return nil }
        do {
            let lm = try await getLightManager()
            let wsEmbedding = try lm.extractSpeakerEmbedding(from: audioSamples)
            AppLog.info("WeSpeaker embedding extracted successfully, dim=\(wsEmbedding.count)")
            return wsEmbedding
        } catch {
            AppLog.warn("Segment voiceprint extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 单条声纹匹配最近联系人（用于实时片段级说话人标识）
    static func matchSingleEmbedding(
        _ embedding: [Float],
        against contacts: [(id: String, name: String, embedding: [Float])],
        threshold: Float = -1
    ) -> (contactId: String, contactName: String, score: Float)? {
        let effectiveThreshold = threshold < 0 ? SettingsManager.shared.matchingThreshold : threshold
        var bestScore: Float = -1
        var bestContact: (id: String, name: String)?
        for contact in contacts {
            let score = cosineSimilarity(embedding, contact.embedding)
            if score > bestScore { bestScore = score; bestContact = (contact.id, contact.name) }
        }
        if let contact = bestContact, bestScore >= effectiveThreshold {
            return (contact.id, contact.name, bestScore)
        }
        return nil
    }

    static func matchSpeakers(
        newEmbeddings: [String: [Float]],
        knownContacts: [(id: String, name: String, embedding: [Float])],
        threshold: Float = -1
    ) -> [String: (contactId: String, contactName: String, score: Float)] {
        let effectiveThreshold = threshold < 0 ? SettingsManager.shared.matchingThreshold : threshold
        var matches: [String: (contactId: String, contactName: String, score: Float)] = [:]
        for (speakerId, newEmb) in newEmbeddings {
            if let match = matchSingleEmbedding(newEmb, against: knownContacts, threshold: effectiveThreshold) {
                matches[speakerId] = match
            }
        }
        return matches
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, magA: Float = 0, magB: Float = 0
        for i in 0..<a.count { dot += a[i]*b[i]; magA += a[i]*a[i]; magB += b[i]*b[i] }
        let den = sqrt(magA)*sqrt(magB)
        return den > 0 ? dot/den : 0
    }
}
