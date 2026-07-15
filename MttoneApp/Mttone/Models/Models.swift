import Foundation

// MARK: - 会议记录

struct Meeting: Identifiable, Codable, Hashable {
    let id: String
    var parentMeetingId: String?
    var title: String
    var location: String?
    var audioPath: String
    var duration: Int // 秒
    var status: Status
    var summary: String?
    var createdAt: Date
    var updatedAt: Date
    var attendees: String? // 新增：空格分隔的参会人姓名列表

    enum Status: String, Codable, CaseIterable {
        case recording
        case pendingDiarization = "pending_diarization"
        case processingLlm = "processing_llm"
        case completed
    }

    /// 便捷初始化：创建新会议
    static func create(
        title: String,
        location: String? = nil,
        parentMeetingId: String? = nil
    ) -> Meeting {
        let now = Date()
        return Meeting(
            id: UUID().uuidString,
            parentMeetingId: parentMeetingId,
            title: title,
            location: location,
            audioPath: "",
            duration: 0,
            status: .recording,
            summary: nil,
            createdAt: now,
            updatedAt: now,
            attendees: nil
        )
    }
}

extension Meeting {
    /// 获取当前会议音频的最新绝对 URL（适配沙盒重新启动后 UUID 发生变化的情况，并动态探测后缀）
    var localAudioURL: URL {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        if !audioPath.isEmpty {
            let lastPathComponent = URL(fileURLWithPath: audioPath).lastPathComponent
            let targetURL = docDir.appendingPathComponent(lastPathComponent)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                return targetURL
            }
        }
        
        let allowedExts = ["wav", "mp3", "m4a", "aac", "flac", "ogg", "caf"]
        for ext in allowedExts {
            let url = docDir.appendingPathComponent("audio_\(id).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        
        return docDir.appendingPathComponent("audio_\(id).wav")
    }

    var audioFileExists: Bool {
        FileManager.default.fileExists(atPath: localAudioURL.path)
    }

    var missingAudioReason: String? {
        if audioFileExists { return nil }
        let url = localAudioURL
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let expectedName = "audio_\(id)"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: docDir.path)) ?? []
        let matching = files.filter { $0.hasPrefix(expectedName) || $0.contains(id) }
        if matching.isEmpty {
            return String(format: loc("audio_file_not_found_diag"), expectedName)
        }
        return String(format: loc("audio_file_missing_diag"), url.lastPathComponent, matching.joined(separator: ", "))
    }
}

// MARK: - 发言切片

struct SpeechClip: Identifiable, Codable, Hashable {
    let id: String
    let meetingId: String
    var speakerLabel: String       // Speaker_1, Speaker_2 ...
    var contactId: String?         // 绑定后的联系人 ID
    var startTime: Double          // 秒
    var endTime: Double            // 秒
    var originalText: String       // ASR 原始转写
    var cleanedText: String?       // LLM 净化后文本
    var audioClipPath: String?     // 试听音频切片路径
    var isKeyClip: Bool            // 是否为代表该 speaker 的核心切片
}

// MARK: - 联系人（声纹人脉库）

struct Contact: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var role: String?
    var company: String?
    var avatarUrl: String?
    var createdAt: Date
    var updatedAt: Date

    var displayName: String {
        if let c = company, !c.isEmpty {
            return "\(name) (\(c))"
        }
        return name
    }

    static func create(name: String, role: String? = nil, company: String? = nil) -> Contact {
        let now = Date()
        return Contact(
            id: UUID().uuidString,
            name: name,
            role: role,
            company: company,
            avatarUrl: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

// MARK: - 私域知识文档

struct KBDocument: Identifiable, Codable, Hashable {
    let id: String
    var filename: String
    var filePath: String
    var textContent: String?
    var createdAt: Date

    static func create(filename: String, filePath: String) -> KBDocument {
        KBDocument(
            id: UUID().uuidString,
            filename: filename,
            filePath: filePath,
            textContent: nil,
            createdAt: Date()
        )
    }
}

// MARK: - 实时转写片段（非持久化，用于 UI 展示）

struct TranscriptSegment: Identifiable, Hashable {
    let id: String
    let startTime: Double
    let endTime: Double
    var text: String
    var speakerLabel: String
    var contactId: String?
    var isFinal: Bool       // 是否为最终结果（非中间识别）

    var formattedTime: String {
        let mins = Int(startTime) / 60
        let secs = Int(startTime) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
