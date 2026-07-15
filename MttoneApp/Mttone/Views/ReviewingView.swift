import SwiftUI
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

/// 录音结束后的回顾页面
struct ReviewingView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(DatabaseManager.self) private var databaseManager
    @State private var activeSegmentId: String? = nil
    @State private var showInspector = true
    @State private var filterSpeaker: String? = nil
    @State private var attendeesString: String = ""
    @State private var showDebugLog = false
    @State private var showRetryConfirm = false
    @State private var pendingRetryAction: (() -> Void)?
    @State private var queuedSegments: [TranscriptSegment] = []
    @State private var queueIndex = 0

    private var diarizationProgress: (separated: Int, total: Int)? {
        guard let meeting = viewModel.currentMeeting, meeting.duration > 0 else { return nil }
        let finals = viewModel.transcriptSegments.filter { $0.isFinal }
        let separated = finals.filter { !$0.speakerLabel.isEmpty }.count
        let estimatedTotal = max(1, Int(Double(meeting.duration) / 3.0))
        let total = max(estimatedTotal, finals.count)
        return (separated, total)
    }
    
    private var retryButtonLabel: String {
        if viewModel.isTranscribingOffline { return loc("analyzing") }
        if viewModel.transcriptSegments.isEmpty { return loc("reanalyze") }
        return loc("continue_analysis")
    }
    
    private var retryButtonIcon: String {
        viewModel.isTranscribingOffline ? "hourglass" : "waveform.badge.magnifyingglass"
    }
    
    private var diarizationProgressText: String? {
        guard let dp = diarizationProgress else { return nil }
        return "\(dp.separated) / \(dp.total) 段"
    }
    
    private var diarizationProgressDone: Bool {
        guard let dp = diarizationProgress else { return false }
        return dp.separated >= dp.total
    }
    
    private var transcriptionPercent: Int? {
        guard viewModel.segmentCount > 0, let meeting = viewModel.currentMeeting else { return nil }
        let estimatedTotal = max(1.0, Double(meeting.duration) / 3.0)
        let raw = Double(viewModel.segmentCount) / max(1.0, estimatedTotal) * 100
        return min(99, max(1, Int(raw)))
    }
    
    @ViewBuilder
    private var reviewToolbar: some View {
        VStack(spacing: 10) {
            // 第一行：继续分析（左对齐）+ 进度数字（右对齐）
            HStack(spacing: 12) {
                if let meeting = viewModel.currentMeeting, meeting.audioFileExists {
                    HStack(spacing: 6) {
                        Button {
                            let hasSegments = !viewModel.transcriptSegments.isEmpty
                            // 检测转写是否明显不完整（段数不足估算的 80%）
                            let isIncomplete: Bool = {
                                guard let m = viewModel.currentMeeting, m.duration > 0 else { return false }
                                let finals = viewModel.transcriptSegments.filter { $0.isFinal }
                                let estimated = max(1, Int(Double(m.duration) / 3.0))
                                return finals.count < estimated * 8 / 10
                            }()
                            let url = meeting.localAudioURL
                            if hasSegments && !isIncomplete {
                                // 段数完整 → 仅做声纹分离
                                viewModel.continueOfflineDiarization(for: meeting.id, audioURL: url)
                            } else if hasSegments && isIncomplete {
                                // 段数不完整 → 确认后重新完整转写
                                pendingRetryAction = { [weak viewModel] in
                                    viewModel?.retryOfflineTranscription(for: meeting.id, audioURL: url)
                                }
                                showRetryConfirm = true
                            } else {
                                // 无段 → 直接完整转写
                                viewModel.retryOfflineTranscription(for: meeting.id, audioURL: url)
                            }
                        } label: {
                            Label(retryButtonLabel, systemImage: retryButtonIcon)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .disabled(viewModel.isTranscribingOffline)
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .controlSize(.regular)
                    }
                }
                Spacer()
                if let text = diarizationProgressText {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(diarizationProgressDone ? Color.secondary : Color.orange)
                }
            }
            
            // 第二行：导出音频 / 导出纪要 / 拷贝纪要（双图标，紧凑排列）
            HStack(spacing: 8) {
                Button {
                    exportAudioFile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.regular)
                .help(loc("export_audio"))
                
                Button {
                    exportMeetingRecord()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.richtext")
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.regular)
                .help(loc("export"))
                
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.plaintext")
                        Image(systemName: "doc.on.doc")
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.regular)
                .help(loc("copy_hint"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var editedAttendeesList: [String] {
        let s = viewModel.currentMeeting?.attendees ?? ""
        if s.isEmpty { return [] }
        return s.split(separator: " ").map(String.init)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if !showInspector {
                        meetingSummaryCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    playbackControlPanel

                    if viewModel.isTranscribingOffline && viewModel.transcriptSegments.isEmpty {
                        transcriptionLoadingView
                    } else if !viewModel.isTranscribingOffline && viewModel.transcriptSegments.isEmpty, let meeting = viewModel.currentMeeting {
                        emptyTranscriptView(meeting: meeting)
                    } else {
                        if viewModel.isTranscribingOffline {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.7)
                                if let pct = transcriptionPercent {
                                    Text(String(format: loc("transcribing_segments"), viewModel.segmentCount, pct))
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text(loc("transcribing_progress"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(.blue.opacity(0.06))
                        }
                        transcriptList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showInspector {
                    Divider()
                    VStack(spacing: 0) {
                        MeetingInfoSidebar(viewModel: viewModel, filterSpeaker: $filterSpeaker, attendeesString: $attendeesString, showSpeakerSections: true)
                            .frame(maxHeight: .infinity)

                        Divider()

                        reviewToolbar
                    }
                    .frame(width: 260)
                    .transition(.move(edge: .trailing))
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemGroupedBackground))
            #endif
            .navigationTitle(loc("review_title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        viewModel.finishReview()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help(loc("back"))
                }
                ToolbarItemGroup(placement: .primaryAction) {
#if DEBUG
                    Button {
                        showDebugLog = true
                    } label: {
                        Image(systemName: "ladybug")
                    }
                    .help(loc("debug_log"))
#endif
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    .frame(width: 32)
                    .help(loc("settings"))

                    NavigationLink(destination: PersonnelManagementView()) {
                        Image(systemName: "person.2")
                    }
                    .frame(width: 32)
                    .help(loc("personnel_voiceprint_help"))

                    Button {
                        withAnimation { showInspector.toggle() }
                    } label: {
                        Image(systemName: "sidebar.right")
                            .foregroundStyle(showInspector ? .purple : .secondary)
                    }
                    .frame(width: 32)
                    .help(loc("meeting_inspector"))
                }
            }
            .onAppear {
                attendeesString = viewModel.currentMeeting?.attendees ?? ""
            }
            .onChange(of: viewModel.transcriptSegments.map(\.speakerLabel)) { _, labels in
                for label in labels {
                    let trimmed = label.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("Speaker_") else { continue }
                    addAttendeeFromLabel(trimmed)
                }
            }
            .onChange(of: viewModel.audioPlayer.currentTime) { _, time in
                // 多段时间重叠时，选当前时间离段中点最近的（避开边界歧义）
                let matching = viewModel.transcriptSegments.filter { $0.startTime <= time && $0.endTime >= time }
                if matching.count == 1 {
                    activeSegmentId = matching[0].id
                } else if let best = matching.min(by: { a, b in
                    let midA = (a.startTime + a.endTime) / 2
                    let midB = (b.startTime + b.endTime) / 2
                    return abs(time - midA) < abs(time - midB)
                }) {
                    activeSegmentId = best.id
                }
            }
            .onChange(of: viewModel.audioPlayer.isPlaying) { _, playing in
                if !playing && !queuedSegments.isEmpty {
                    // 当前段播完，自动播放下一个
                    playNextQueued()
                }
            }
            .onChange(of: filterSpeaker) { _, _ in
                // 切换/清除说话人过滤时，清空播放队列
                queuedSegments = []
                viewModel.audioPlayer.playbackEndTime = nil
            }
            .sheet(isPresented: $showDebugLog) {
                DebugLogView()
            }
            .alert(loc("confirm_retranscribe"), isPresented: $showRetryConfirm) {
                Button(loc("cancel"), role: .cancel) { pendingRetryAction = nil }
                Button(loc("confirm"), role: .destructive) {
                    pendingRetryAction?()
                    pendingRetryAction = nil
                }
            } message: {
                Text(String(format: loc("confirm_retranscribe_msg"), viewModel.transcriptSegments.count))
            }
        }
    }

    private func addAttendeeFromLabel(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let current = attendeesString
        var list = current.isEmpty ? [] : current.split(separator: " ").map(String.init)
        guard !list.contains(trimmed) else {
            return
        }
        list.append(trimmed)
        let newList = list.joined(separator: " ")
        attendeesString = newList
        viewModel.addAttendee(trimmed)
    }

    // MARK: - 空白文本加载视图
    private var transcriptionLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(loc("transcribing_hint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyTranscriptView(meeting: Meeting) -> some View {
        VStack(spacing: 12) {
            if viewModel.isTranscribingOffline {
                ProgressView()
                    .controlSize(.large)
                Text(loc("transcribing_progress"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                if meeting.status == .pendingDiarization || meeting.status == .completed || meeting.status == .processingLlm {
                    Text(loc("transcript_missing"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(loc("transcript_missing_hint"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if meeting.audioFileExists {
                        Button(loc("rerun_transcription")) {
                            viewModel.isTranscribingOffline = true
                            let url = meeting.localAudioURL
                            viewModel.retryOfflineTranscription(for: meeting.id, audioURL: url)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    } else {
                        Text(loc("audio_file_not_found"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text(loc("no_transcript"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Button(loc("load_from_db")) {
                    viewModel.loadSegmentsFromDatabase(meetingId: meeting.id)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.loadSegmentsFromDatabase(meetingId: meeting.id)
        }
    }

    private var transcriptList: some View {
        UnifiedTranscriptEditor(
            segments: $viewModel.transcriptSegments,
            filterSpeaker: $filterSpeaker,
            activeSegmentId: $activeSegmentId,
            meetingAttendees: $attendeesString,
            contacts: databaseManager.fetchAllContacts().map { $0.name },
            onPlaySegment: { seg in playSegment(seg) },
            onSpeakerChanged: { segId, newSpeaker in
                    viewModel.updateSpeakerLabel(id: segId, newLabel: newSpeaker)
                    addAttendeeFromLabel(newSpeaker)
            }
        )
        .padding()
    }

    // MARK: - 会议信息卡片

    private var meetingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let meeting = viewModel.currentMeeting {
                Text(meeting.title)
                    .font(.title3)
                    .fontWeight(.bold)
                HStack(spacing: 16) {
                    Label(formatCreatedAt(meeting.createdAt), systemImage: "calendar")
                    if let location = meeting.location {
                        Label(location, systemImage: "mappin")
                    }
                    Label(String(format: loc("segments_count"), viewModel.transcriptSegments.filter { $0.isFinal }.count), systemImage: "text.bubble")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - 音频播放

    private var playbackControlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(formatTime(viewModel.audioPlayer.currentTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { viewModel.audioPlayer.currentTime },
                    set: { viewModel.audioPlayer.seek(to: $0) }
                ), in: 0...max(viewModel.audioPlayer.duration, 1.0))
                .tint(.purple)

                Text(formatTime(viewModel.audioPlayer.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                Button {
                    if viewModel.audioPlayer.isPlaying {
                        viewModel.audioPlayer.pause()
                    } else {
                        if let meeting = viewModel.currentMeeting {
                            let url = meeting.localAudioURL
                            if viewModel.audioPlayer.currentTime >= viewModel.audioPlayer.duration - 0.1 || !viewModel.audioPlayer.hasPlayer {
                                viewModel.audioPlayer.startPlaying(url: url)
                            } else {
                                viewModel.audioPlayer.resume()
                            }
                        }
                    }
                } label: {
                    Image(systemName: viewModel.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.purple, in: Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    ForEach(0..<8) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(viewModel.audioPlayer.isPlaying ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat.random(in: 4...20) * CGFloat(viewModel.audioPlayer.meterLevel))
                    }
                }
                .frame(width: 40, height: 24)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: viewModel.audioPlayer.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { viewModel.audioPlayer.volume },
                        set: { viewModel.audioPlayer.volume = $0 }
                    ), in: 0...1.0)
                    .frame(width: 100)
                    .tint(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - 辅助

    private func exportAudioFile() {
        guard let meeting = viewModel.currentMeeting else { return }
        let sourceURL = meeting.localAudioURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.title = loc("export_audio")
        let ext = sourceURL.pathExtension
        savePanel.nameFieldStringValue = "\(meeting.title).\(ext)"
        if !ext.isEmpty {
            savePanel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .audio]
        }
        savePanel.canCreateDirectories = true
        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            try? FileManager.default.copyItem(at: sourceURL, to: destURL)
        }
        #endif
    }

    private func copyToClipboard() {
        guard let meeting = viewModel.currentMeeting else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
        let notSpec = loc("not_specified")
        var text = """
        \(String(format: loc("copy_topic"), meeting.title))
        \(String(format: loc("copy_location"), meeting.location ?? notSpec))
        \(String(format: loc("copy_time"), f.string(from: meeting.createdAt)))
        \(String(format: loc("copy_attendees"), meeting.attendees ?? notSpec))

        """

        for seg in viewModel.transcriptSegments.filter({ $0.isFinal }) {
            let time = formatTime(seg.startTime)
            text += "[\(time)] \(seg.speakerLabel): \(seg.text)\n"
        }

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatCreatedAt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    private func exportMeetingRecord() {
        guard let meeting = viewModel.currentMeeting else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let notSpec = loc("not_specified")

        var text = """
        \(String(format: loc("copy_topic"), meeting.title))
        \(String(format: loc("copy_location"), meeting.location ?? notSpec))
        \(String(format: loc("copy_time"), formatter.string(from: meeting.createdAt)))
        \(String(format: loc("record_duration_fmt"), formatDuration(TimeInterval(meeting.duration))))
        \(String(format: loc("copy_attendees"), meeting.attendees ?? notSpec))
        
        ========================================
        \(loc("export_record_title"))
        ========================================
        
        """

        let segments = viewModel.transcriptSegments.filter { $0.isFinal }
        for seg in segments {
            let time = formatTime(seg.startTime)
            text += "[\(time)] \(seg.speakerLabel): \(seg.text)\n\n"
        }

        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.title = loc("export_meeting_record")
        savePanel.nameFieldStringValue = "\(meeting.title).txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let mins = Int(t)/60, secs = Int(t)%60
        return String(format: loc("duration_min_sec"), mins, secs)
    }

    private func playSegment(_ segment: TranscriptSegment) {
        if let meeting = viewModel.currentMeeting {
            let url = meeting.localAudioURL
            if !viewModel.audioPlayer.hasPlayer {
                viewModel.audioPlayer.startPlaying(url: url)
            }
        }
        
        // 如果当前按说话人过滤，构建该说话人的连续播放队列
        if let speaker = filterSpeaker {
            let sameSpeaker = viewModel.transcriptSegments
                .filter { $0.speakerLabel == speaker && $0.isFinal }
                .sorted { $0.startTime < $1.startTime }
            if let idx = sameSpeaker.firstIndex(where: { $0.id == segment.id }) {
                queuedSegments = Array(sameSpeaker.dropFirst(idx))
                queueIndex = 0
            } else {
                queuedSegments = []
            }
        } else {
            queuedSegments = []
        }
        
        viewModel.audioPlayer.playbackEndTime = segment.endTime
        viewModel.audioPlayer.seek(to: segment.startTime)
        if !viewModel.audioPlayer.isPlaying {
            viewModel.audioPlayer.resume()
        }
    }
    
    private func playNextQueued() {
        guard queueIndex < queuedSegments.count else {
            queuedSegments = []
            return
        }
        let seg = queuedSegments[queueIndex]
        queueIndex += 1
        // 短暂延迟，让音频引擎完成上一段的停止状态转换
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak viewModel] in
            viewModel?.audioPlayer.playbackEndTime = seg.endTime
            viewModel?.audioPlayer.seek(to: seg.startTime)
            if viewModel?.audioPlayer.isPlaying == false {
                viewModel?.audioPlayer.resume()
            }
        }
    }

}
