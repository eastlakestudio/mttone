import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 录音结束后的回顾页面
struct ReviewingView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(DatabaseManager.self) private var databaseManager
    @State private var activeSegmentId: String? = nil
    @State private var showInspector = true
    @State private var filterSpeaker: String? = nil
    @State private var attendeesString: String = ""
    @State private var showDebugLog = false

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
                                Text("正在转写... (\(viewModel.segmentCount) 段)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                if viewModel.segmentCount > 0, let meeting = viewModel.currentMeeting {
                                    let pct = min(99, Int(Double(viewModel.segmentCount) / max(1, Double(meeting.duration) / 3.0) * 100))
                                    Text("~\(pct)%")
                                        .font(.caption).monospacedDigit().foregroundStyle(.purple)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 4)
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

                        // 会议专用工具栏
                        HStack(spacing: 12) {
                            Button {
                                showDebugLog = true
                            } label: {
                                Image(systemName: "ladybug")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("调试日志")

                            Spacer()

                            if let meeting = viewModel.currentMeeting, meeting.audioFileExists {
                                Button {
                                    let url = meeting.localAudioURL
                                    viewModel.retryOfflineTranscription(for: meeting.id, audioURL: url)
                                } label: {
                                    Label(viewModel.isTranscribingOffline ? "分析中..." : (viewModel.transcriptSegments.isEmpty ? "重新分析" : "继续分析"),
                                          systemImage: viewModel.isTranscribingOffline ? "hourglass" : "waveform.badge.magnifyingglass")
                                        .font(.caption)
                                }
                                .disabled(viewModel.isTranscribingOffline)
                                .buttonStyle(.bordered)
                                .tint(.purple)
                                .controlSize(.small)
                            }

                            Spacer()

                            Button {
                                exportMeetingRecord()
                            } label: {
                                Label("导出", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
            .navigationTitle("会议回顾")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink(destination: PersonnelManagementView()) {
                        Label("人员与声纹", systemImage: "person.3.sequence")
                    }.help("全局人员与声纹管理")

                    Button {
                        withAnimation { showInspector.toggle() }
                    } label: {
                        Image(systemName: "sidebar.right")
                            .foregroundStyle(showInspector ? .purple : .secondary)
                    }
                    .help("会议属性检查器")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        viewModel.finishReview()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                attendeesString = viewModel.currentMeeting?.attendees ?? ""
            }
            .onChange(of: viewModel.transcriptSegments.map(\.speakerLabel)) { _, labels in
                for label in labels {
                    addAttendeeFromLabel(label)
                }
            }
            .onChange(of: viewModel.audioPlayer.currentTime) { _, time in
                if let seg = viewModel.transcriptSegments.first(where: { $0.startTime <= time && $0.endTime >= time }) {
                    activeSegmentId = seg.id
                }
            }
            .sheet(isPresented: $showDebugLog) {
                DebugLogView()
            }
        }
    }

    private func addAttendeeFromLabel(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let current = attendeesString
        var list = current.isEmpty ? [] : current.split(separator: " ").map(String.init)
        guard !list.contains(trimmed) else {
            try? "[Mttone] SKIP: \(trimmed) already in '\(current)'".write(toFile: "/tmp/mttone_debug.log", atomically: true, encoding: .utf8)
            return
        }
        list.append(trimmed)
        let newList = list.joined(separator: " ")
        attendeesString = newList
        viewModel.addAttendee(trimmed)
        try? "[Mttone] DONE: \(trimmed) → '\(newList)' (attendeesString now: \(attendeesString))".write(toFile: "/tmp/mttone_debug.log", atomically: true, encoding: .utf8)
    }

    // MARK: - 空白文本加载视图
    private var transcriptionLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("正在使用本地大模型高精度转写...")
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
                Text("正在转写中...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                if meeting.status == .pendingDiarization || meeting.status == .completed || meeting.status == .processingLlm {
                    Text("转写数据缺失")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("录音文件可能尚未完成离线转写")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if meeting.audioFileExists {
                        Button("重新运行离线转写") {
                            viewModel.isTranscribingOffline = true
                            let url = meeting.localAudioURL
                            viewModel.retryOfflineTranscription(for: meeting.id, audioURL: url)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    } else {
                        Text("录音文件不存在")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("暂无转写内容")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Button("从数据库加载") {
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
                try? "[Mttone] onSpeakerChanged: \(segId) → \(newSpeaker)".write(toFile: "/tmp/mttone_debug.log", atomically: true, encoding: .utf8)
                if let idx = viewModel.transcriptSegments.firstIndex(where: { $0.id == segId }) {
                    viewModel.transcriptSegments[idx].speakerLabel = newSpeaker
                }
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
                    Label("\(viewModel.transcriptSegments.filter { $0.isFinal }.count) 段", systemImage: "text.bubble")
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

        var text = """
        会议主题: \(meeting.title)
        会议地点: \(meeting.location ?? "未指定")
        开始时间: \(formatter.string(from: meeting.createdAt))
        录音时长: \(formatDuration(TimeInterval(meeting.duration)))
        参会人员: \(meeting.attendees ?? "未指定")
        
        ========================================
        会议记录
        ========================================
        
        """

        let segments = viewModel.transcriptSegments.filter { $0.isFinal }
        for seg in segments {
            let time = formatTime(seg.startTime)
            text += "[\(time)] \(seg.speakerLabel): \(seg.text)\n\n"
        }

        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.title = "导出会议记录"
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
        return "\(mins)分\(secs)秒"
    }

    private func playSegment(_ segment: TranscriptSegment) {
        if let meeting = viewModel.currentMeeting {
            let url = meeting.localAudioURL
            if !viewModel.audioPlayer.hasPlayer {
                viewModel.audioPlayer.startPlaying(url: url)
            }
        }
        viewModel.audioPlayer.playbackEndTime = segment.endTime
        viewModel.audioPlayer.seek(to: segment.startTime)
        if !viewModel.audioPlayer.isPlaying {
            viewModel.audioPlayer.resume()
        }
    }

    private func addAttendeeFromTranscript(_ name: String) {
        viewModel.addAttendee(name)
    }
}
