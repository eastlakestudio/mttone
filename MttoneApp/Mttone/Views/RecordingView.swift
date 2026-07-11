import SwiftUI

/// 录音进行中的主界面
struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 顶部录音状态栏
            recordingHeader

            // 实时转写内容
            transcriptList

            // 底部控制栏
            controlBar
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemGroupedBackground))
        #endif
    }

    // MARK: - 录音状态栏

    private var recordingHeader: some View {
        VStack(spacing: 12) {
            HStack {
                // 红色脉冲指示器
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.red.opacity(0.4), lineWidth: 3)
                            .scaleEffect(1.5)
                            .opacity(viewModel.currentAmplitude > 0.01 ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentAmplitude)
                    )

                Text("录音中")
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer()

                Text(viewModel.formattedDuration)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.medium)
            }

            // 音量可视化条
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * CGFloat(min(viewModel.currentAmplitude * 5, 1.0)),
                        height: 4
                    )
                    .animation(.easeOut(duration: 0.1), value: viewModel.currentAmplitude)
            }
            .frame(height: 4)

            if let meeting = viewModel.currentMeeting {
                HStack {
                    Text(meeting.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let location = meeting.location {
                        Spacer()
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - 转写列表

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.transcriptSegments.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("正在聆听...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    ForEach(viewModel.transcriptSegments) { segment in
                        TranscriptBubble(segment: segment)
                            .id(segment.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.transcriptSegments.count) { _, _ in
                if let lastSegment = viewModel.transcriptSegments.last {
                    withAnimation {
                        proxy.scrollTo(lastSegment.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 底部控制栏

    private var controlBar: some View {
        HStack {
            Spacer()

            Button {
                viewModel.stopRecording()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("停止录音")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(.red, in: Capsule())
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - 转写气泡

struct TranscriptBubble: View {
    let segment: TranscriptSegment
    var isActive: Bool = false
    var attendees: [String] = [] // 新增：可用的参会人列表
    var onTextChange: ((String) -> Void)? = nil
    var onSpeakerChange: ((String) -> Void)? = nil

    @State private var editedText: String
    @State private var isEditingSpeaker = false
    @State private var editedSpeaker: String

    init(segment: TranscriptSegment, isActive: Bool = false, attendees: [String] = [], onTextChange: ((String) -> Void)? = nil, onSpeakerChange: ((String) -> Void)? = nil) {
        self.segment = segment
        self.isActive = isActive
        self.attendees = attendees
        self.onTextChange = onTextChange
        self.onSpeakerChange = onSpeakerChange
        self._editedText = State(initialValue: segment.text)
        self._editedSpeaker = State(initialValue: segment.speakerLabel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if onSpeakerChange != nil {
                    HStack(spacing: 2) {
                        TextField("说话人", text: $editedSpeaker, onEditingChanged: { editing in
                            if !editing && editedSpeaker != segment.speakerLabel {
                                onSpeakerChange?(editedSpeaker)
                            }
                        })
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                        .textFieldStyle(.plain)
                        .frame(width: 80)
                        
                        if !attendees.isEmpty {
                            Menu {
                                ForEach(attendees, id: \.self) { person in
                                    Button(person) {
                                        editedSpeaker = person
                                        onSpeakerChange?(person)
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.purple)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .frame(width: 12)
                        }
                    }
                } else {
                    Text(segment.speakerLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                }

                Text(segment.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !segment.isFinal {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            if onTextChange != nil {
                TextField("输入转写内容...", text: $editedText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textFieldStyle(.plain)
                    .onChange(of: editedText) { _, newValue in
                        onTextChange?(newValue)
                    }
            } else {
                Text(segment.text)
                    .font(.body)
                    .foregroundStyle(segment.isFinal ? .primary : .secondary)
                    .opacity(segment.isFinal ? 1 : 0.7)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive 
                      ? Color.purple.opacity(0.15) 
                      : (segment.isFinal ? Color.gray.opacity(0.15) : Color.gray.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onChange(of: segment.text) { _, newText in
            if editedText != newText && onTextChange == nil {
                editedText = newText
            }
        }
    }
}
