import SwiftUI

/// 录音 ViewModel：协调 AudioRecorder、DatabaseManager 和 UI 状态
@MainActor
@Observable
final class RecordingViewModel {

    // MARK: - UI 状态

    var meetingStatus: MeetingStatus = .idle
    var currentMeeting: Meeting?
    var transcriptSegments: [TranscriptSegment] = []
    var recordingDuration: TimeInterval = 0
    var showNewMeetingSheet = false
    var errorAlert: String?

    // MARK: - 新建会议表单

    var formTitle = ""
    var formLocation = ""
    var formAttendees = ""
    var shouldExtendLastMeeting = false // 是否延续上一次会议的开关
    var selectedParentMeetingId: String? = nil
    var formCreatedAt = Date()

    enum RecordingMode {
        case liveRecording
        case importFile
    }

    var recordingMode: RecordingMode = .liveRecording
    var showingMeetingEditor = false

    enum MeetingStatus {
        case idle
        case recording
        case reviewing
    }

    // MARK: - 依赖

    var audioPlayer = AudioPlayer() // 回放播放器
    let audioRecorder: AudioRecorder
    private let databaseManager: DatabaseManager
    
    // 离线转写状态
    var isTranscribingOffline: Bool = false
    
    // 定时器
    private var durationTimer: Timer?

    init(audioRecorder: AudioRecorder, databaseManager: DatabaseManager) {
        self.audioRecorder = audioRecorder
        self.databaseManager = databaseManager
    }

    // MARK: - 录音控制

    /// 用户点击"开始新录音"
    func onTapStartRecording() {
        showNewMeetingSheet = true
    }

    /// 用户在弹窗中确认开始
    func startRecording() async {
        showNewMeetingSheet = false

        // 1. 请求权限
        let granted = await audioRecorder.requestPermissions()
        guard granted else {
            errorAlert = audioRecorder.errorMessage ?? "权限被拒绝"
            return
        }

        // 2. 创建会议记录
        let title = formTitle.isEmpty
            ? "会议记录_\(formattedDate)"
            : formTitle

        // 如果勾选了延续上一次会议，则获取选中的关联会议 ID
        var parentId: String? = nil
        if shouldExtendLastMeeting {
            parentId = selectedParentMeetingId
        }

        var meeting = Meeting.create(
            title: title,
            location: formLocation.isEmpty ? nil : formLocation,
            parentMeetingId: parentId
        )
        meeting.createdAt = formCreatedAt
        meeting.updatedAt = formCreatedAt

        do {
            try databaseManager.createMeeting(meeting)
        } catch {
            errorAlert = "创建会议失败: \(error.localizedDescription)"
            return
        }

        // 3. 启动录音，传入上下文高频词汇（如标题、地点、参会人）
        let audioDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioPath = audioDir.appendingPathComponent("audio_\(meeting.id).wav")

        var contextualWords: [String] = []
        if !formTitle.isEmpty { contextualWords.append(formTitle) }
        if !formLocation.isEmpty { contextualWords.append(formLocation) }
        if !formAttendees.isEmpty { contextualWords.append(contentsOf: formAttendees.split(separator: " ").map(String.init)) }

        do {
            // 提前加载 Whisper 模型，以免在录音循环中报错“模型尚未加载完成”
            try await WhisperService.shared.initialize()
            try audioRecorder.startRecording(meetingId: meeting.id, savePath: audioPath, contextualStrings: contextualWords)
        } catch {
            errorAlert = "启动录音失败: \(error.localizedDescription)"
            return
        }

        // 4. 更新状态
        currentMeeting = meeting
        meetingStatus = .recording
        recordingDuration = 0
        transcriptSegments = []
        resetForm()

        // 5. 启动计时器
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration += 1
                self.transcriptSegments = self.audioRecorder.segments
            }
        }
        self.durationTimer = timer
    }

    /// 停止录音，进入回顾模式
    func stopRecording() {
        durationTimer?.invalidate()
        durationTimer = nil

        let duration = audioRecorder.stopRecording()

        // 更新数据库状态并补充音频路径
        if let meeting = currentMeeting {
            let audioDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioPath = audioDir.appendingPathComponent("audio_\(meeting.id).wav").path
            
            // 更新数据库
            try? databaseManager.updateMeetingStatus(
                id: meeting.id,
                status: .pendingDiarization,
                duration: duration
            )
            
            // 确保本地对象里也更新一下音频路径以便播放
            currentMeeting?.audioPath = audioPath
            
            // 设置播放器总时长为录音实际秒数
            audioPlayer.duration = TimeInterval(duration)
            audioPlayer.currentTime = 0
        }

        // 最终同步 segments，并强制将它们标记为 final（因为引擎已经被强行停止，可能来不及发出 final 标志）
        transcriptSegments = audioRecorder.segments.map { segment in
            var s = segment
            s.isFinal = true
            return s
        }

        // 延迟 0.15 秒改变状态，确保 macOS 文件句柄从写入锁定状态安全释放
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.meetingStatus = .reviewing
            self.runOfflineTranscription()
        }
    }

    /// 运行本地大模型进行高精度离线转写
    private func runOfflineTranscription() {
        guard let meeting = currentMeeting else { return }
        let audioURL = meeting.localAudioURL

        runOfflineTranscription(for: meeting.id, audioURL: audioURL)
    }

    func retryOfflineTranscription(for meetingId: String, audioURL: URL) {
        runOfflineTranscription(for: meetingId, audioURL: audioURL)
    }

    private func runOfflineTranscription(for meetingId: String, audioURL: URL) {
        isTranscribingOffline = true
        Task {
            do {
                try await WhisperService.shared.initialize()
                
                async let whisperTask = WhisperService.shared.transcribe(audioURL: audioURL, meetingId: meetingId)
                async let diarizationTask = DiarizationService.shared.diarize(audioURL: audioURL)
                
                let offlineSegments = try await whisperTask
                let speakerSegments = try await diarizationTask
                
                let alignedSegments = self.alignSpeakerLabels(transcripts: offlineSegments, diarization: speakerSegments)
                
                await MainActor.run {
                    if alignedSegments.isEmpty == false {
                        self.transcriptSegments = alignedSegments
                    }
                    self.saveSegmentsToDatabase(meetingId: meetingId)
                    self.isTranscribingOffline = false
                }
            } catch {
                print("[RecordingViewModel] 离线大模型转写失败: \(error)")
                await MainActor.run {
                    self.errorAlert = "离线大模型转写/分离失败:\n\(error.localizedDescription)"
                    self.saveSegmentsToDatabase(meetingId: meetingId)
                    self.isTranscribingOffline = false
                }
            }
        }
    }

    func importAudioFile(from sourceURL: URL, title: String? = nil, location: String? = nil) async {
        let meetingId = UUID().uuidString
        let ext = sourceURL.pathExtension.lowercased()
        let allowedExts = ["wav", "mp3", "m4a", "aac", "flac", "ogg", "caf"]
        guard allowedExts.contains(ext) else {
            errorAlert = "不支持的音频格式: .\(ext)"
            return
        }

        let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = destDir.appendingPathComponent("audio_\(meetingId).\(ext)")

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            errorAlert = "文件复制失败: \(error.localizedDescription)"
            return
        }

        let fileName = sourceURL.lastPathComponent
        let meetingTitle = title ?? fileName.replacingOccurrences(
            of: ".\(ext)", with: "",
            options: .caseInsensitive
        )

        var parentId: String? = nil
        if shouldExtendLastMeeting {
            parentId = selectedParentMeetingId
        }

        let meeting = Meeting(
            id: meetingId,
            parentMeetingId: parentId,
            title: meetingTitle,
            location: location ?? "外部导入",
            audioPath: destURL.path,
            duration: 0,
            status: .pendingDiarization,
            summary: nil,
            createdAt: formCreatedAt,
            updatedAt: formCreatedAt
        )

        do {
            try databaseManager.createMeeting(meeting)
        } catch {
            errorAlert = "创建会议失败: \(error.localizedDescription)"
            try? FileManager.default.removeItem(at: destURL)
            return
        }

        currentMeeting = meeting
        audioPlayer.duration = 0
        audioPlayer.currentTime = 0
        transcriptSegments = []
        meetingStatus = .reviewing

        runOfflineTranscription(for: meetingId, audioURL: destURL)
    }

    /// 更新当前会议的元数据并写入数据库 (非模态修改用)
    func updateMeetingMetadata(title: String, location: String?, createdAt: Date, attendees: String, duration: Int? = nil) {
        guard var meeting = currentMeeting else { return }
        meeting.title = title
        meeting.location = location
        meeting.createdAt = createdAt
        meeting.attendees = attendees
        if let d = duration {
            meeting.duration = d
        }
        
        do {
            try databaseManager.updateMeetingInfo(
                id: meeting.id,
                title: title,
                location: location,
                createdAt: createdAt,
                attendees: attendees,
                duration: duration
            )
            currentMeeting = meeting
        } catch {
            print("[RecordingViewModel] Failed to update meeting metadata: \(error)")
        }
    }
    
    // MARK: - 持久化与加载
    
    /// 从数据库加载历史转写记录
    func loadSegmentsFromDatabase(meetingId: String) {
        let clips = databaseManager.fetchSpeechClips(meetingId: meetingId)
        transcriptSegments = clips.map { clip in
            TranscriptSegment(
                id: clip.id,
                startTime: clip.startTime,
                endTime: clip.endTime,
                text: clip.originalText,
                speakerLabel: clip.speakerLabel,
                contactId: clip.contactId,
                isFinal: true
            )
        }
    }
    
    /// 将当前内存中的片段持久化到数据库
    private func saveSegmentsToDatabase(meetingId: String) {
        do {
            try databaseManager.deleteSpeechClips(meetingId: meetingId)
            for segment in transcriptSegments {
                let clip = SpeechClip(
                    id: segment.id,
                    meetingId: meetingId,
                    speakerLabel: segment.speakerLabel,
                    contactId: segment.contactId,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    originalText: segment.text,
                    cleanedText: nil,
                    audioClipPath: nil,
                    isKeyClip: false
                )
                try databaseManager.saveSpeechClip(clip)
            }
        } catch {
            print("[RecordingViewModel] ERROR: Failed to save segments to database: \(error)")
        }
    }

    /// 更新片段文本
    func updateSegmentText(id: String, newText: String) {
        if let index = transcriptSegments.firstIndex(where: { $0.id == id }) {
            transcriptSegments[index].text = newText
        }
    }

    func mergeWithPrevious(segmentId: String) {
        guard let index = transcriptSegments.firstIndex(where: { $0.id == segmentId }), index > 0 else { return }
        let current = transcriptSegments[index]
        let previous = transcriptSegments[index - 1]
        guard current.speakerLabel == previous.speakerLabel else { return }

        let merged = TranscriptSegment(
            id: previous.id,
            startTime: previous.startTime,
            endTime: current.endTime,
            text: previous.text + "\n" + current.text,
            speakerLabel: previous.speakerLabel,
            contactId: previous.contactId,
            isFinal: true
        )
        transcriptSegments[index - 1] = merged
        transcriptSegments.remove(at: index)
    }

    func updateLocalSpeakerLabel(id: String, newLabel: String) {
        guard let index = transcriptSegments.firstIndex(where: { $0.id == id }) else { return }
        var contact = databaseManager.fetchContact(byName: newLabel)
        if contact == nil {
            contact = Contact.create(name: newLabel)
            try? databaseManager.saveContact(contact!)
        }
        transcriptSegments[index].speakerLabel = newLabel
        transcriptSegments[index].contactId = contact?.id
    }

    /// 拆分气泡片段并分配说话人
    func splitSegment(id: String, text1: String, text2: String, newSpeakerForPart2: String? = nil) {
        guard let index = transcriptSegments.firstIndex(where: { $0.id == id }) else { return }
        let original = transcriptSegments[index]
        
        let totalDuration = original.endTime - original.startTime
        let totalChars = max(1, text1.count + text2.count)
        let ratio = Double(text1.count) / Double(totalChars)
        let splitTime = original.startTime + totalDuration * ratio
        
        var speaker2 = original.speakerLabel
        var contactId2 = original.contactId
        
        if let newSpeaker = newSpeakerForPart2?.trimmingCharacters(in: .whitespaces), !newSpeaker.isEmpty {
            speaker2 = newSpeaker
            var contact = databaseManager.fetchContact(byName: newSpeaker)
            if contact == nil {
                let newContact = Contact.create(name: newSpeaker)
                try? databaseManager.saveContact(newContact)
                contact = newContact
            }
            contactId2 = contact?.id
        }
        
        let seg1 = TranscriptSegment(
            id: UUID().uuidString,
            startTime: original.startTime,
            endTime: splitTime,
            text: text1,
            speakerLabel: original.speakerLabel,
            contactId: original.contactId,
            isFinal: original.isFinal
        )
        
        let seg2 = TranscriptSegment(
            id: UUID().uuidString,
            startTime: splitTime,
            endTime: original.endTime,
            text: text2,
            speakerLabel: speaker2,
            contactId: contactId2,
            isFinal: original.isFinal
        )
        
        // 更新内存数组
        transcriptSegments.remove(at: index)
        transcriptSegments.insert(seg2, at: index)
        transcriptSegments.insert(seg1, at: index)
        
        // 同步持久化到数据库
        if let meetingId = currentMeeting?.id {
            // 转为 SpeechClip 进行更新
            let clip1 = SpeechClip(id: seg1.id, meetingId: meetingId, speakerLabel: seg1.speakerLabel, contactId: seg1.contactId, startTime: seg1.startTime, endTime: seg1.endTime, originalText: seg1.text, cleanedText: nil, audioClipPath: nil, isKeyClip: false)
            let clip2 = SpeechClip(id: seg2.id, meetingId: meetingId, speakerLabel: seg2.speakerLabel, contactId: seg2.contactId, startTime: seg2.startTime, endTime: seg2.endTime, originalText: seg2.text, cleanedText: nil, audioClipPath: nil, isKeyClip: false)
            
            do {
                try databaseManager.splitSpeechClip(oldClipId: original.id, newClip1: clip1, newClip2: clip2)
            } catch {
                print("[RecordingViewModel] ERROR: Failed to split segment in db: \(error)")
            }
        }
    }

    /// 获取当前所有片段中出现的不重复说话人列表
    var uniqueSpeakers: [String] {
        var speakers = Set<String>()
        for segment in transcriptSegments {
            speakers.insert(segment.speakerLabel)
        }
        return Array(speakers).sorted()
    }

    /// 全局重命名说话人（并同步更新所有相关片段）
    func globalRenameSpeaker(oldName: String, newName: String, contactId: String? = nil) {
        guard oldName != newName else { return }
        for i in 0..<transcriptSegments.count {
            if transcriptSegments[i].speakerLabel == oldName {
                transcriptSegments[i].speakerLabel = newName
                if let cid = contactId {
                    transcriptSegments[i].contactId = cid
                }
            }
        }
    }

    /// 更新片段发言人标签
    func updateSpeakerLabel(id: String, newLabel: String) {
        if let index = transcriptSegments.firstIndex(where: { $0.id == id }) {
            let oldLabel = transcriptSegments[index].speakerLabel
            
            var contact = databaseManager.fetchContact(byName: newLabel)
            if contact == nil {
                contact = Contact.create(name: newLabel)
                do {
                    try databaseManager.saveContact(contact!)
                } catch {
                    print("[RecordingViewModel] ERROR saving contact: \(error)")
                }
            }
            
            globalRenameSpeaker(oldName: oldLabel, newName: newLabel, contactId: contact?.id)
            
            if let meetingId = currentMeeting?.id {
                let clips = databaseManager.fetchSpeechClips(meetingId: meetingId)
                for clip in clips {
                    if clip.speakerLabel == oldLabel || clip.speakerLabel == newLabel {
                        try? databaseManager.updateSpeechClipContact(
                            clipId: clip.id,
                            speakerLabel: newLabel,
                            contactId: contact?.id
                        )
                    }
                }
            }
        }
    }

    /// 返回首页
    func finishReview() {
        if let meeting = currentMeeting {
            // 在返回首页前，将用户的任何手工修改（文字、标签）覆盖保存到数据库
            saveSegmentsToDatabase(meetingId: meeting.id)
        }
        
        audioPlayer.stop() // 回收播放器资源
        meetingStatus = .idle
        currentMeeting = nil
        transcriptSegments = []
        recordingDuration = 0
    }

    // MARK: - 格式化

    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var currentAmplitude: Float {
        audioRecorder.currentAmplitude
    }

    // MARK: - 私有方法

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func resetForm() {
        formTitle = ""
        formLocation = ""
        formAttendees = ""
        shouldExtendLastMeeting = false
        selectedParentMeetingId = nil
        formCreatedAt = Date()
        recordingMode = .liveRecording
    }

    /// 双模态对齐聚类算法：将声纹分离出的纯时间区间，匹配到带有文字的时间区间上
    private func alignSpeakerLabels(transcripts: [TranscriptSegment], diarization: [DiarizedSegment]) -> [TranscriptSegment] {
        var results = transcripts
        
        for i in 0..<results.count {
            let tSegment = results[i]
            var bestSpeaker: String? = nil
            var maxOverlap: Double = 0.0
            var nearestDistance: Double = .infinity
            var nearestSpeaker: String? = nil
            
            for dSegment in diarization {
                // 计算两个时间区间的重叠面积 (Intersection over Union - 核心思路)
                let overlapStart = max(tSegment.startTime, dSegment.startTime)
                let overlapEnd = min(tSegment.endTime, dSegment.endTime)
                
                if overlapEnd > overlapStart {
                    let overlapDuration = overlapEnd - overlapStart
                    if overlapDuration > maxOverlap {
                        maxOverlap = overlapDuration
                        bestSpeaker = dSegment.speakerId
                    }
                }
                
                // 计算距离，用于 fallback（如果没有任何重叠，则找最近的说话人）
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
