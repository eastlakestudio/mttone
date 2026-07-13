import SwiftUI

/// 录音进行中的主界面
struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel
    @State private var showInspector = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                recordingHeader
                transcriptList
                controlBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showInspector {
                Divider()
                MeetingInfoSidebar(viewModel: viewModel, showSpeakerSections: false)
                    .frame(width: 260)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemGroupedBackground))
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation { showInspector.toggle() }
                } label: {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(showInspector ? .purple : .secondary)
                }
                .help("会议信息")
            }
        }
    }

    // MARK: - 录音状态栏

    private var recordingHeader: some View {
        VStack(spacing: 12) {
            HStack {
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
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * CGFloat(min(viewModel.currentAmplitude * 5, 1.0)), height: 4)
                    .animation(.easeOut(duration: 0.1), value: viewModel.currentAmplitude)
            }
            .frame(height: 4)
            if let meeting = viewModel.currentMeeting {
                HStack {
                    Text(meeting.title).font(.subheadline).foregroundStyle(.secondary)
                    if let location = meeting.location {
                        Spacer()
                        Label(location, systemImage: "mappin").font(.caption).foregroundStyle(.tertiary)
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
                            Text("正在聆听...").font(.subheadline).foregroundStyle(.secondary)
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
                    withAnimation { proxy.scrollTo(lastSegment.id, anchor: .bottom) }
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
    var attendees: [String] = []
    var contacts: [String] = []
    var onTextChange: ((String) -> Void)? = nil
    var onSpeakerChange: ((String) -> Void)? = nil
    var onPlay: (() -> Void)? = nil
    var onSplit: ((String, String, String?) -> Void)? = nil
    var onMerge: (() -> Void)? = nil

    @State private var editedText: String
    @State private var showRenamePopover = false
    @State private var newSpeakerTempName = ""

    private var otherContacts: [String] {
        contacts.filter { !attendees.contains($0) }
    }

    init(segment: TranscriptSegment, isActive: Bool = false, attendees: [String] = [], contacts: [String] = [], onTextChange: ((String) -> Void)? = nil, onSpeakerChange: ((String) -> Void)? = nil, onPlay: (() -> Void)? = nil, onSplit: ((String, String, String?) -> Void)? = nil, onMerge: (() -> Void)? = nil) {
        self.segment = segment
        self.isActive = isActive
        self.attendees = attendees
        self.contacts = contacts
        self.onTextChange = onTextChange
        self.onSpeakerChange = onSpeakerChange
        self.onPlay = onPlay
        self.onSplit = onSplit
        self.onMerge = onMerge
        self._editedText = State(initialValue: segment.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            speakerBadge

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(segment.formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let onPlay = onPlay {
                        Button(action: onPlay) {
                            Image(systemName: "play.circle.fill").font(.caption).foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    if let onMerge = onMerge {
                        Button(action: onMerge) {
                            Image(systemName: "arrow.up.and.person.rectangle.turn.left")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("合并到上一段")
                    }
                    if !segment.isFinal {
                        ProgressView().scaleEffect(0.5)
                    }
                }

                if onTextChange != nil {
                    TextEditor(text: $editedText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 24, maxHeight: 120)
                        .onChange(of: editedText) { _, newValue in
                            if newValue.contains("\n") {
                                let parts = newValue.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                                if parts.count >= 2 {
                                    let t1 = parts[0], t2 = parts[1]
                                    editedText = parts[0]
                                    onSplit?(t1, t2, nil)
                                } else {
                                    editedText = newValue.replacingOccurrences(of: "\n", with: "")
                                }
                            } else {
                                onTextChange?(newValue)
                            }
                        }
                } else {
                    Text("\(segment.speakerLabel): \(segment.text)")
                        .font(.body)
                        .foregroundStyle(segment.isFinal ? .primary : .secondary)
                        .opacity(segment.isFinal ? 1 : 0.7)
                        .frame(minHeight: 20, alignment: .topLeading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.purple.opacity(0.12) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .onChange(of: segment.text) { _, newText in
            editedText = newText
        }
    }

    // MARK: - 说话人标签

    private var speakerBadge: some View {
        Group {
            if onSpeakerChange != nil {
                Menu {
                    if !attendees.isEmpty {
                        Section("参会人") {
                            ForEach(attendees, id: \.self) { p in Button(p) { onSpeakerChange?(p) } }
                        }
                    }
                    if !otherContacts.isEmpty {
                        Section("声纹字典") {
                            ForEach(otherContacts, id: \.self) { n in Button(n) { onSpeakerChange?(n) } }
                        }
                    }
                    Section { Button("新建说话人...") { newSpeakerTempName = ""; showRenamePopover = true } }
                } label: {
                    Text(segment.speakerLabel)
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(speakerColor, in: Capsule())
                }
                .menuStyle(.button).buttonStyle(.plain)
                .popover(isPresented: $showRenamePopover) {
                    VStack(spacing: 8) {
                        Text("新建声纹人").font(.caption).foregroundStyle(.secondary)
                        TextField("姓名", text: $newSpeakerTempName).textFieldStyle(.roundedBorder)
                            .onSubmit { confirmNewSpeaker() }
                        HStack {
                            Spacer()
                            Button("取消") { showRenamePopover = false }
                            Button("确定") { confirmNewSpeaker() }.buttonStyle(.borderedProminent)
                        }
                    }
                    .padding().frame(width: 200)
                }
            } else {
                Text(segment.speakerLabel)
                    .font(.caption).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(speakerColor, in: Capsule())
            }
        }
        .frame(width: 64, alignment: .leading)
        .padding(.top, 2)
    }

    private var speakerColor: Color {
        let c: [Color] = [.purple, .blue, .orange, .green, .pink, .teal, .indigo, .mint]
        return c[abs(segment.speakerLabel.hashValue) % c.count]
    }

    private func confirmNewSpeaker() {
        let name = newSpeakerTempName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { onSpeakerChange?(name); showRenamePopover = false }
    }
}
