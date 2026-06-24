import SwiftUI

/// 录音结束后的回顾页面
struct ReviewingView: View {
    @Bindable var viewModel: RecordingViewModel
    @State private var activeSegmentId: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 会议摘要卡片
                meetingSummaryCard

                // 音频播放控制面板
                playbackControlPanel

                // 转写记录列表与加载状态
                if viewModel.isTranscribingOffline {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("正在使用本地大模型高精度转写...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.transcriptSegments.filter { $0.isFinal }) { segment in
                                TranscriptBubble(
                                    segment: segment,
                                    isActive: segment.id == activeSegmentId,
                                    onTextChange: { newText in
                                        viewModel.updateSegmentText(id: segment.id, newText: newText)
                                    },
                                    onSpeakerChange: { newSpeaker in
                                        viewModel.updateSpeakerLabel(id: segment.id, newLabel: newSpeaker)
                                    }
                                )
                                .id(segment.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.audioPlayer.currentTime) { _, newTime in
                        // 寻找当前播放时间所在的片段
                        if let activeSegment = viewModel.transcriptSegments.last(where: { $0.startTime <= newTime && $0.endTime >= newTime }) {
                            if activeSegment.id != activeSegmentId {
                                activeSegmentId = activeSegment.id
                                withAnimation {
                                    proxy.scrollTo(activeSegment.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                } // End else
            }
            .background(Color(.windowBackgroundColor))
            .navigationTitle("会议回顾")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        viewModel.finishReview()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

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

                    Label(
                        "\(viewModel.transcriptSegments.filter { $0.isFinal }.count) 段",
                        systemImage: "text.bubble"
                    )
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
    }

    private func formatCreatedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private var playbackControlPanel: some View {
        VStack(spacing: 12) {
            // 进度控制
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

            // 控制条：播放、暂停、音量
            HStack(spacing: 20) {
                // 播放/暂停按钮
                Button {
                    if viewModel.audioPlayer.isPlaying {
                        viewModel.audioPlayer.pause()
                    } else {
                        if let meeting = viewModel.currentMeeting {
                            // 动态从 Documents 文件夹计算当前会议的绝对物理路径，避开硬编码/已过期的沙盒哈希
                            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let url = docDir.appendingPathComponent("audio_\(meeting.id).m4a")
                            
                            // 无论是否播放过，如果当前时间等于总时长或者还没实例化，都进行全新播放
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

                // 播放音量大小指示（实时变动）
                HStack(spacing: 4) {
                    ForEach(0..<8) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(viewModel.audioPlayer.isPlaying ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat.random(in: 4...20) * CGFloat(viewModel.audioPlayer.meterLevel))
                            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.5), value: viewModel.audioPlayer.meterLevel)
                    }
                }
                .frame(width: 40, height: 24)

                Spacer()

                // 音量滑块
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

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
