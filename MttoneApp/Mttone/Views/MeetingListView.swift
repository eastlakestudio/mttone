import SwiftUI

/// 会议列表页（首页）
struct MeetingListView: View {
    @Bindable var recordingVM: RecordingViewModel
    @Environment(DatabaseManager.self) private var databaseManager
    @State private var listVM: MeetingListViewModel?
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部状态栏
                statusHeader

                // 会议列表
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
            .navigationTitle("Mttone")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            let granted = await recordingVM.audioRecorder.requestPermissions()
                            await MainActor.run {
                                if granted {
                                    recordingVM.onTapStartRecording()
                                } else {
                                    permissionAlertMessage = recordingVM.audioRecorder.errorMessage ?? "麦克风或语音识别权限被拒绝"
                                    showPermissionAlert = true
                                }
                            }
                        }
                    } label: {
                        Label("开始新录音", systemImage: "mic.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
            .sheet(isPresented: $recordingVM.showNewMeetingSheet) {
                NewMeetingSheet(viewModel: recordingVM)
            }
            .alert("权限不足", isPresented: $showPermissionAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("\(permissionAlertMessage)\n\n请前往「系统设置 - 隐私与安全性 - 麦克风/语音识别」中开启权限。如果是由于重签名导致卡死，您可能需要重启电脑或在终端重置 TCC 权限。")
            }
            .onAppear {
                if listVM == nil {
                    listVM = MeetingListViewModel(databaseManager: databaseManager)
                }
                listVM?.loadMeetings()
            }
            .onChange(of: recordingVM.meetingStatus) { _, newStatus in
                // 当录音或回顾状态结束返回到空闲时，重新刷一次列表
                if newStatus == .idle {
                    listVM?.loadMeetings()
                }
            }
        }
    }

    // MARK: - 子视图

    private var statusHeader: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.green)
            Text("准备就绪")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("本地离线会议纪要与声纹人脉库")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
            Text("点击右上角「开始新录音」启动本地 ASR")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private func meetingList(_ meetings: [Meeting]) -> some View {
        List(meetings) { meeting in
            Button {
                recordingVM.currentMeeting = meeting
                // 根据会议的音频路径，填充回放路径
                let finalPath = meeting.audioPath.isEmpty 
                    ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("audio_\(meeting.id).wav").path 
                    : meeting.audioPath
                recordingVM.currentMeeting?.audioPath = finalPath
                
                // 将历史会议的 duration (秒) 赋值给播放器
                recordingVM.audioPlayer.duration = TimeInterval(meeting.duration)
                recordingVM.audioPlayer.currentTime = 0
                
                // 从数据库加载该历史会议的语音片段，以便同步回放
                recordingVM.loadSegmentsFromDatabase(meetingId: meeting.id)
                recordingVM.meetingStatus = .reviewing
            } label: {
                MeetingRow(meeting: meeting)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - 会议列表行

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            statusIcon
                .frame(width: 40, height: 40)
                .background(statusColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let location = meeting.location {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(formattedDuration)
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
        case .pendingDiarization: return "待分离"
        case .processingLlm: return "AI 处理中"
        case .completed: return "已完成"
        }
    }

    private var formattedDuration: String {
        let mins = meeting.duration / 60
        let secs = meeting.duration % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
