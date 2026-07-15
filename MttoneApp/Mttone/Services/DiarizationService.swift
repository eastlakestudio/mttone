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
    let speakerEmbeddings: [String: [Float]]
}

actor DiarizationService {
    static let shared = DiarizationService()
    
    private var manager: OfflineDiarizerManager?
    
    private func getManager() async throws -> OfflineDiarizerManager {
        if let manager = manager {
            return manager
        }
        let config = OfflineDiarizerConfig(clusteringThreshold: 0.82)
        let newManager = OfflineDiarizerManager(config: config)
        try await newManager.prepareModels()
        self.manager = newManager
        return newManager
    }

    func diarize(audioURL: URL) async throws -> [DiarizedSegment] {
        let output = try await diarizeWithEmbeddings(audioURL: audioURL)
        return output.segments
    }

    func diarizeWithEmbeddings(audioURL: URL) async throws -> DiarizationOutput {
        AppLog.info("声纹分离引擎启动: audio=\(audioURL.lastPathComponent)")
        let manager = try await getManager()
        let samples = try AudioConverter().resampleAudioFile(path: audioURL.path)
        AppLog.info("音频重采样完成: \(samples.count) 样本")
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
        
        return DiarizationOutput(segments: segments, speakerEmbeddings: remappedDB)
    }

    static func matchSpeakers(
        newEmbeddings: [String: [Float]],
        knownContacts: [(id: String, name: String, embedding: [Float])],
        threshold: Float = 0.65
    ) -> [String: (contactId: String, contactName: String, score: Float)] {
        var matches: [String: (contactId: String, contactName: String, score: Float)] = [:]
        for (speakerId, newEmb) in newEmbeddings {
            var bestScore: Float = -1
            var bestContact: (id: String, name: String)?
            for contact in knownContacts {
                let score = cosineSimilarity(newEmb, contact.embedding)
                if score > bestScore { bestScore = score; bestContact = (contact.id, contact.name) }
            }
            if let contact = bestContact, bestScore >= threshold {
                matches[speakerId] = (contact.id, contact.name, bestScore)
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
