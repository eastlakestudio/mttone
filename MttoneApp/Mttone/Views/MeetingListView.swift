import SwiftUI
#if os(macOS)
import AppKit
#endif
import AVFoundation

/// 会议列表页（首页）
struct MeetingListView: View {
    @Bindable var recordingVM: RecordingViewModel
    @Environment(DatabaseManager.self) private var databaseManager
    @State private var listVM: MeetingListViewModel?
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var showDeleteSheet = false
    @State private var deleteGroupMeetings: [Meeting] = []
    @State private var deleteGroupClipCounts: [String: Int] = [:]
    @State private var isExportingFile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusHeader

                if let vm = listVM {
                    if vm.meetings.isEmpty {
                        emptyState
                    } else {
                        meetingList(vm.meetings)
                    }
                } else {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemGroupedBackground))
            #endif
            .navigationTitle("听纪")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink(destination: SettingsView()) {
                        Label("配置", systemImage: "gearshape")
                    }

                    NavigationLink(destination: PersonnelManagementView()) {
                        Label("人员与声纹", systemImage: "person.3.sequence")
                    }
                    .help("全局人员与声纹管理")

                    Button {
                        recordingVM.onTapStartRecording()
                    } label: {
                        Label("开始会议", systemImage: "pencil.and.list.clipboard")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(SettingsManager.shared.isModelDownloading || SettingsManager.shared.modelVersion.isEmpty)
                }
            }
            .sheet(isPresented: $recordingVM.showNewMeetingSheet) {
                NewMeetingSheet(viewModel: recordingVM)
            }
            .sheet(isPresented: $showDeleteSheet) {
                DeleteMeetingSheet(
                    meetings: deleteGroupMeetings,
                    speechClipCounts: deleteGroupClipCounts,
                    onDelete: {
                        for m in deleteGroupMeetings {
                            try? databaseManager.deleteMeeting(id: m.id)
                        }
                        listVM?.loadMeetings()
                    },
                    onExportFile: { filePath in
                        exportAudioFile(filePath)
                    }
                )
            }
            .alert("权限不足", isPresented: $showPermissionAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("\(permissionAlertMessage)\n\n请前往「系统设置 - 隐私与安全性 - 麦克风/语音识别」中开启权限。")
            }
            .onAppear {
                // 检测已下载的模型版本
                let s = SettingsManager.shared
                if s.modelVersion.isEmpty, !s.modelPath.isEmpty {
                    // 尝试从路径检测（模型在 modelPath/models/argmaxinc/whisperkit-coreml/ 下）
                    let repoPath = URL(fileURLWithPath: s.modelPath)
                        .appendingPathComponent("models/argmaxinc/whisperkit-coreml").path
                    for v in ["openai_whisper-large-v3", "openai_whisper-large-v3_turbo", "openai_whisper-medium"] {
                        let check = URL(fileURLWithPath: repoPath).appendingPathComponent(v)
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: check.path, isDirectory: &isDir), isDir.boolValue {
                            s.modelVersion = v
                            break
                        }
                    }
                }
                if listVM == nil {
                    listVM = MeetingListViewModel(databaseManager: databaseManager)
                }
                listVM?.loadMeetings()
            }
            .onChange(of: recordingVM.meetingStatus) { _, newStatus in
                if newStatus == .idle {
                    listVM?.loadMeetings()
                }
            }
        }
    }

    // MARK: - 子视图

    private var statusHeader: some View {
        let settings = SettingsManager.shared
        return HStack {
            Image(systemName: "bolt.fill").foregroundStyle(.green)
            Text("准备就绪").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if settings.isModelDownloading {
                ProgressView().scaleEffect(0.7)
                Text("正在下载语音模型... \(Int(settings.modelDownloadProgress * 100))%")
                    .font(.caption).foregroundStyle(.orange)
            } else if settings.modelVersion.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                Text("语音模型未下载").font(.caption).foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                Text("\(settings.modelVersion) 已就绪").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("暂无会议记录")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("点击右上角「开始会议」选择录音模式")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private func meetingList(_ meetings: [Meeting]) -> some View {
        List(meetings) { meeting in
            Button {
                recordingVM.currentMeeting = meeting
                let finalPath = meeting.localAudioURL.path
                recordingVM.currentMeeting?.audioPath = finalPath

                let log = { (msg: String) in
                    let df = DateFormatter(); df.dateFormat = "HH:mm:ss.SSS"
                    let line = "\(df.string(from: Date())) [Duration] \(msg)\n"
                    if let d = line.data(using: .utf8), let h = FileHandle(forWritingAtPath: "/tmp/auranote_diag.log") {
                        h.seekToEndOfFile(); h.write(d); h.closeFile()
                    }
                }

                log("打开会议: id=\(meeting.id), DB时长=\(meeting.duration)s, 音频路径=\(finalPath), 文件存在=\(FileManager.default.fileExists(atPath: finalPath))")

                // 探测音频实际时长
                var duration = TimeInterval(meeting.duration)
                if let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: finalPath)) {
                    if player.duration > 0 {
                        duration = player.duration
                        log("AVAudioPlayer探测时长: \(Int(duration))s")
                    } else {
                        log("AVAudioPlayer返回时长=0")
                    }
                } else {
                    log("AVAudioPlayer初始化失败")
                }
                recordingVM.audioPlayer.duration = duration
                recordingVM.audioPlayer.currentTime = 0
                log("最终设置 audioPlayer.duration = \(Int(duration))s")

                recordingVM.loadSegmentsFromDatabase(meetingId: meeting.id)
                recordingVM.meetingStatus = .reviewing
            } label: {
                MeetingRow(meeting: meeting)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    deleteGroupMeetings = databaseManager.fetchMeetingGroup(id: meeting.id)
                    var counts: [String: Int] = [:]
                    for m in deleteGroupMeetings {
                        counts[m.id] = databaseManager.fetchSpeechClipsCount(meetingId: m.id)
                    }
                    deleteGroupClipCounts = counts
                    showDeleteSheet = true
                } label: {
                    Label("删除会议", systemImage: "trash")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func exportAudioFile(_ sourcePath: String) {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard FileManager.default.fileExists(atPath: sourcePath) else { return }
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.title = "另存录音文件"
        savePanel.nameFieldStringValue = sourceURL.lastPathComponent
        savePanel.allowedContentTypes = [.audio]
        savePanel.canCreateDirectories = true
        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            try? FileManager.default.copyItem(at: sourceURL, to: destURL)
        }
        #endif
    }
}

// MARK: - 会议列表行

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 40, height: 40)
                .background(statusColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(formattedTimeRange, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let location = meeting.location {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label(formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            statusBadge
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(statusColor)
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var iconName: String {
        switch meeting.status {
        case .recording: return "mic.fill"
        case .pendingDiarization: return "person.wave.2"
        case .processingLlm: return "brain"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch meeting.status {
        case .recording: return .red
        case .pendingDiarization: return .orange
        case .processingLlm: return .blue
        case .completed: return .green
        }
    }

    private var statusText: String {
        switch meeting.status {
        case .recording: return "录音中"
        case .pendingDiarization: return "未分离"
        case .processingLlm: return "分离未完成"
        case .completed: return "完成分离"
        }
    }

    private var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: meeting.createdAt)
        let end = formatter.string(from: meeting.createdAt.addingTimeInterval(Double(meeting.duration)))
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dayFormatter.string(from: meeting.createdAt)
        
        if meeting.duration > 0 {
            return "\(dateStr) \(start)-\(end)"
        } else {
            return "\(dateStr) \(start) - ..."
        }
    }

    private var formattedDuration: String {
        let mins = meeting.duration / 60
        let secs = meeting.duration % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - 删除会议确认弹窗

struct DeleteMeetingSheet: View {
    let meetings: [Meeting]
    let speechClipCounts: [String: Int]
    let onDelete: () -> Void
    let onExportFile: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("删除会议")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("以下关联会议将被删除（含录音文件、转写文本和说话人分离数据），此操作不可撤销。在删除前，您可以点击录音文件右侧的导出按钮手动导出所需文件。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(meetings, id: \.id) { meeting in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.purple)
                                Text(meeting.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                statusBadge(meeting)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    let fileName = URL(fileURLWithPath: meeting.audioPath).lastPathComponent
                                    Text("录音文件: \(fileName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        onExportFile(meeting.audioPath)
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                    .help("另存录音文件")
                                }

                                let clipCount = speechClipCounts[meeting.id] ?? 0
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("语音剪辑: \(clipCount) 条")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text("创建: \(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.leading, 24)
                        }
                        .padding(12)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        if meeting.id != meetings.last?.id {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(.purple.opacity(0.2))
                                    .frame(width: 2, height: 16)
                                    .padding(.leading, 30)
                                Text("延续")
                                    .font(.caption2)
                                    .foregroundStyle(.purple.opacity(0.6))
                                    .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack(spacing: 12) {
                Button("取消") { dismiss() }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("确认删除", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 300)
    }

    private func statusBadge(_ meeting: Meeting) -> some View {
        Text(statusText(meeting))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(meeting).opacity(0.12))
            .foregroundStyle(statusColor(meeting))
            .clipShape(Capsule())
    }

    private func statusText(_ meeting: Meeting) -> String {
        switch meeting.status {
        case .recording: return "录音中"
        case .pendingDiarization: return "待分离"
        case .processingLlm: return "AI 处理中"
        case .completed: return "已完成"
        }
    }

    private func statusColor(_ meeting: Meeting) -> Color {
        switch meeting.status {
        case .recording: return .red
        case .pendingDiarization: return .orange
        case .processingLlm: return .blue
        case .completed: return .green
        }
    }
}
