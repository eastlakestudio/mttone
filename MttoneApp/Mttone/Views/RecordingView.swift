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
    var contacts: [String] = []  // 新增：全局联系人列表
    var onTextChange: ((String) -> Void)? = nil
    var onSpeakerChange: ((String) -> Void)? = nil
    var onPlay: (() -> Void)? = nil
    var onSplit: ((String, String, String?) -> Void)? = nil

    @State private var editedText: String
    @State private var isEditingSpeaker = false
    @State private var editedSpeaker: String
    @State private var showRenamePopover = false
    @State private var newSpeakerTempName = ""
    @State private var showSplitPopover = false
    @State private var splitText1 = ""
    @State private var splitText2 = ""
    @State private var newSpeakerForPart2 = ""

    private var otherContacts: [String] {
        contacts.filter { !attendees.contains($0) }
    }

    init(segment: TranscriptSegment, isActive: Bool = false, attendees: [String] = [], contacts: [String] = [], onTextChange: ((String) -> Void)? = nil, onSpeakerChange: ((String) -> Void)? = nil, onPlay: (() -> Void)? = nil, onSplit: ((String, String, String?) -> Void)? = nil) {
        self.segment = segment
        self.isActive = isActive
        self.attendees = attendees
        self.contacts = contacts
        self.onTextChange = onTextChange
        self.onSpeakerChange = onSpeakerChange
        self.onPlay = onPlay
        self.onSplit = onSplit
        self._editedText = State(initialValue: segment.text)
        self._editedSpeaker = State(initialValue: segment.speakerLabel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if onSpeakerChange != nil {
                    Menu {
                        if !attendees.isEmpty {
                            Section("当前会议参会人") {
                                ForEach(attendees, id: \.self) { person in
                                    Button(person) {
                                        onSpeakerChange?(person)
                                    }
                                }
                            }
                        }
                        
                        if !otherContacts.isEmpty {
                            Section("声纹字典联系人") {
                                ForEach(otherContacts, id: \.self) { contactName in
                                    Button(contactName) {
                                        onSpeakerChange?(contactName)
                                    }
                                }
                            }
                        }
                        
                        Section("全局重命名") {
                            Button("新建声纹人并绑定...") {
                                newSpeakerTempName = ""
                                showRenamePopover = true
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(segment.speakerLabel)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.purple)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(.purple)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .popover(isPresented: $showRenamePopover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("输入新名字进行全局重命名")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("新名字", text: $newSpeakerTempName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !newSpeakerTempName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        onSpeakerChange?(newSpeakerTempName)
                                        showRenamePopover = false
                                    }
                                }
                            HStack {
                                Spacer()
                                Button("取消") {
                                    showRenamePopover = false
                                }
                                Button("确定") {
                                    if !newSpeakerTempName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        onSpeakerChange?(newSpeakerTempName)
                                        showRenamePopover = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .font(.caption)
                        }
                        .padding()
                        .frame(width: 220)
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
                    
                if let onPlay = onPlay {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                if onSplit != nil {
                    Button {
                        splitText1 = editedText
                        splitText2 = ""
                        newSpeakerForPart2 = ""
                        showSplitPopover = true
                    } label: {
                        Image(systemName: "scissors")
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("在此处拆分文本")
                    .popover(isPresented: $showSplitPopover) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("拆分并重分配")
                                .font(.headline)
                            
                            Text("第一段内容 (在里面按回车切分):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextEditor(text: $splitText1)
                                .frame(height: 80)
                                .onChange(of: splitText1) { _, newValue in
                                    if newValue.contains("\n") {
                                        let parts = newValue.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                                        if parts.count == 2 {
                                            splitText1 = String(parts[0])
                                            splitText2 = String(parts[1])
                                        }
                                    }
                                }
                            
                            if !splitText2.isEmpty {
                                Text("第二段内容:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextEditor(text: $splitText2)
                                    .frame(height: 60)
                                
                                Text("分配第二段给说话人:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Menu {
                                    if !attendees.isEmpty {
                                        Section("当前会议参会人") {
                                            ForEach(attendees, id: \.self) { person in
                                                Button(person) {
                                                    newSpeakerForPart2 = person
                                                }
                                            }
                                        }
                                    }
                                    if !otherContacts.isEmpty {
                                        Section("声纹字典联系人") {
                                            ForEach(otherContacts, id: \.self) { contactName in
                                                Button(contactName) {
                                                    newSpeakerForPart2 = contactName
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(newSpeakerForPart2.isEmpty ? "保持相同 (\(segment.speakerLabel))" : newSpeakerForPart2)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                    }
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .menuStyle(.button)
                                .buttonStyle(.plain)
                                
                                TextField("或输入新说话人姓名...", text: $newSpeakerForPart2)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Spacer()
                                Button("取消") {
                                    showSplitPopover = false
                                }
                                Button("确认拆分") {
                                    if !splitText1.isEmpty && !splitText2.isEmpty {
                                        onSplit?(splitText1, splitText2, newSpeakerForPart2.isEmpty ? nil : newSpeakerForPart2)
                                        showSplitPopover = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(splitText1.isEmpty || splitText2.isEmpty)
                            }
                        }
                        .padding()
                        .frame(width: 320)
                    }
                }

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
                    .onChange(of: editedText) { oldValue, newValue in
                        if newValue.contains("\n") {
                            // User pressed Enter -> split!
                            let parts = newValue.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                            if parts.count == 2 {
                                let t1 = String(parts[0])
                                let t2 = String(parts[1])
                                // Revert to t1 immediately to avoid newline artifacts
                                editedText = t1
                                onSplit?(t1, t2, nil)
                            }
                        } else {
                            onTextChange?(newValue)
                        }
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
            editedText = newText
        }
        .onChange(of: segment.speakerLabel) { _, newLabel in
            editedSpeaker = newLabel
        }
    }
}
