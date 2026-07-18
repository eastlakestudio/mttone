import Foundation

/// 声纹-转写时间轴对齐服务
/// 双模态对齐聚类算法：将声纹分离出的纯时间区间，匹配到带有文字的转写时间区间上
enum SpeakerAlignmentService {

    /// 将声纹分离的时间区间标注到转写片段上
    /// - Parameters:
    ///   - transcripts: 待标注的转写片段列表
    ///   - diarization: 声纹分离结果（说话人 + 时间区间）
    /// - Returns: 标注了 speakerLabel 的转写片段
    static func align(transcripts: [TranscriptSegment], diarization: [DiarizedSegment]) -> [TranscriptSegment] {
        guard !diarization.isEmpty else { return transcripts }
        var results = transcripts

        for i in 0..<results.count {
            let tSegment = results[i]
            var bestSpeaker: String?
            var maxOverlap: Double = 0.0
            var nearestDistance: Double = .infinity
            var nearestSpeaker: String?

            for dSegment in diarization {
                // 计算两个时间区间的重叠面积，优先选重叠最大的说话人
                let overlapStart = max(tSegment.startTime, dSegment.startTime)
                let overlapEnd = min(tSegment.endTime, dSegment.endTime)

                if overlapEnd > overlapStart {
                    let overlapDuration = overlapEnd - overlapStart
                    if overlapDuration > maxOverlap {
                        maxOverlap = overlapDuration
                        bestSpeaker = dSegment.speakerId
                    }
                }

                // 计算时间距离，用于 fallback（如果没有任何重叠，找最近的说话人）
                let distance: Double
                if tSegment.endTime <= dSegment.startTime {
                    distance = dSegment.startTime - tSegment.endTime
                } else if tSegment.startTime >= dSegment.endTime {
                    distance = tSegment.startTime - dSegment.endTime
                } else {
                    distance = 0
                }

                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestSpeaker = dSegment.speakerId
                }
            }

            // 优先使用重叠面积最大的说话人，否则 fallback 到时间上最接近的说话人
            if let speaker = bestSpeaker ?? nearestSpeaker {
                results[i].speakerLabel = speaker
            }
        }

        return results
    }
}
