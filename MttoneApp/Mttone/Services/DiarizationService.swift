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
    let speakerEmbeddings: [String: [Float]]  // speakerId → 256维声纹向量
}

actor DiarizationService {
    static let shared = DiarizationService()
    
    private var manager: OfflineDiarizerManager?
    
    private func getManager() async throws -> OfflineDiarizerManager {
        if let manager = manager {
            return manager
        }
        let config = OfflineDiarizerConfig(clusteringThreshold: 0.75)
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
        let manager = try await getManager()
        let samples = try AudioConverter().resampleAudioFile(path: audioURL.path)
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
        
        // 记录声纹向量是否存在
        let speakerDB = result.speakerDatabase ?? [:]
        let embCount = speakerDB.count
        let embSpeakers = speakerDB.keys.sorted().joined(separator: ", ")
        let fullMsg = "\(msg), 声纹向量: \(embCount)个 (\(embSpeakers))"
        
        let segSamples = segments.prefix(8).map { "\($0.speakerId)[\(Int($0.startTime))-\(Int($0.endTime))s]" }.joined(separator: ", ")
        let detailMsg = "\(fullMsg), 样例: \(segSamples)"
        
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss.SSS"
        let line = "\(df.string(from: Date())) [Diar] \(detailMsg)\n"
        if let d = line.data(using: String.Encoding.utf8), let h = FileHandle(forWritingAtPath: "/tmp/mttone_diag.log") {
            h.seekToEndOfFile(); h.write(d); h.closeFile()
        } else { try? line.write(toFile: "/tmp/mttone_diag.log", atomically: true, encoding: String.Encoding.utf8) }
        
        return DiarizationOutput(segments: segments, speakerEmbeddings: speakerDB)
    }

    /// 余弦相似度匹配：将新声纹向量与已存储的联系人向量比较
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
                if score > bestScore {
                    bestScore = score
                    bestContact = (contact.id, contact.name)
                }
            }
            
            if let contact = bestContact, bestScore >= threshold {
                matches[speakerId] = (contact.id, contact.name, bestScore)
            }
        }
        return matches
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dotProduct: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        let denominator = sqrt(magA) * sqrt(magB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}
