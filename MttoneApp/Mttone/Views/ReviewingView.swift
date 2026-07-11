import SwiftUI

/// 录音结束后的回顾页面
struct ReviewingView: View {
    @Bindable var viewModel: RecordingViewModel
    @State private var activeSegmentId: String? = nil
    
    // 非模态侧边属性检查器状态
    @State private var showInspector = true
    @State private var editedTitle = ""
    @State private var editedLocation = ""
    @State private var editedCreatedAt = Date()
    @State private var editedEndedAt = Date()
    @State private var newAttendeeName = ""
    @State private var showDatePickerPopover = false
    @State private var showEndDatePickerPopover = false

    // 解析当前参会人为独立的名字数组
    private var editedAttendeesList: [String] {
        let attendeesString = viewModel.currentMeeting?.attendees ?? ""
        if attendeesString.isEmpty { return [] }
        return attendeesString.split(separator: " ").map(String.init)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // 左侧核心工作区
                VStack(spacing: 0) {
                    // 折叠状态下在顶部展示简易卡片；展开侧边栏时隐藏以留出空间
                    if !showInspector {
                        meetingSummaryCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

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
                                            attendees: editedAttendeesList, // 传入参会人列表打通快捷说话人重命名
                                            onTextChange: { newText in
                                                viewModel.updateSegmentText(id: segment.id, newText: newText)
                                            },
                                            onSpeakerChange: { newSpeaker in
                                                viewModel.updateSpeakerLabel(id: segment.id, newLabel: newSpeaker)
                                            }
                                        )
                                        .id(segment.id)
                                        .onTapGesture {
                                            playSegment(segment)
                                        }
                                        // 鼠标悬浮时显示为手指指针（提示可点击）
                                        #if os(macOS)
                                        .onHover { isHovered in
                                            if isHovered {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        #endif
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 右侧可折叠的属性面板 (Inspector Sidebar)
                if showInspector {
                    Divider()
                    inspectorSidebar
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            showInspector.toggle()
                        }
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
                loadMetadata()
            }
            .onChange(of: viewModel.currentMeeting) { _, _ in
                loadMetadata()
            }
        }
    }

    // MARK: - 会议信息只读扁平卡片 (收起检查器时在顶部展示)
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

    // MARK: - 右侧属性检查器面板
    private var inspectorSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("会议属性检查器")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. 会议主题
                    VStack(alignment: .leading, spacing: 6) {
                        Text("会议主题")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("输入会议主题", text: $editedTitle)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                saveMetadata()
                            }
                    }
                    
                    // 2. 开始时间
                    VStack(alignment: .leading, spacing: 6) {
                        Text("开始时间")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            showDatePickerPopover = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.purple)
                                Text(formatCreatedAt(editedCreatedAt))
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDatePickerPopover) {
                            DatePicker("", selection: $editedCreatedAt, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding()
                                .frame(width: 280, height: 320)
                                .onChange(of: editedCreatedAt) { _, _ in
                                    saveMetadata()
                                }
                        }
                    }
                    
                    // 2.5 结束时间
                    VStack(alignment: .leading, spacing: 6) {
                        Text("结束时间")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            showEndDatePickerPopover = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.purple)
                                Text(formatCreatedAt(editedEndedAt))
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showEndDatePickerPopover) {
                            DatePicker("", selection: $editedEndedAt, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding()
                                .frame(width: 280, height: 320)
                                .onChange(of: editedEndedAt) { _, _ in
                                    saveMetadata()
                                }
                        }
                    }
                    
                    // 3. 会议地点
                    VStack(alignment: .leading, spacing: 6) {
                        Text("会议地点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("输入地点", text: $editedLocation)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                saveMetadata()
                            }
                    }
                    
                    // 4. 参会人员
                    VStack(alignment: .leading, spacing: 6) {
                        Text("参会人员")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // 标签流式排布列表
                        let list = editedAttendeesList
                        if !list.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(list, id: \.self) { person in
                                    HStack(spacing: 4) {
                                        Text(person)
                                            .font(.subheadline)
                                        Button {
                                            removeAttendee(person)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.purple.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.bottom, 4)
                        }
                        
                        // 追加参会人输入框
                        HStack {
                            TextField("添加人...", text: $newAttendeeName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addAttendee()
                                }
                            Button {
                                addAttendee()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.purple)
                            }
                            .buttonStyle(.plain)
                            .disabled(newAttendeeName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    
                    // 5. 说话人匹配
                    VStack(alignment: .leading, spacing: 6) {
                        Divider().padding(.vertical, 4)
                        Text("说话人匹配")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        let uniqueSpeakers = viewModel.uniqueSpeakers
                        if uniqueSpeakers.isEmpty {
                            Text("暂无说话人")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(uniqueSpeakers, id: \.self) { speaker in
                                HStack {
                                    Text(speaker)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    Menu {
                                        ForEach(editedAttendeesList, id: \.self) { person in
                                            Button(person) {
                                                viewModel.globalRenameSpeaker(oldName: speaker, newName: person)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(editedAttendeesList.contains(speaker) ? "已绑定" : "选择参会人")
                                                .foregroundStyle(editedAttendeesList.contains(speaker) ? .green : .secondary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                        }
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .menuStyle(.borderlessButton)
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(.trailing, 2) // 规避滚动条遮挡
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    // MARK: - 辅助存取与逻辑处理
    private func loadMetadata() {
        if let meeting = viewModel.currentMeeting {
            editedTitle = meeting.title
            editedLocation = meeting.location ?? ""
            editedCreatedAt = meeting.createdAt
            editedEndedAt = meeting.createdAt.addingTimeInterval(TimeInterval(meeting.duration))
        }
    }
    
    private func saveMetadata() {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let loc = editedLocation.trimmingCharacters(in: .whitespaces)
        let location = loc.isEmpty ? nil : loc
        
        let attendeesStr = viewModel.currentMeeting?.attendees ?? ""
        let duration = max(0, Int(editedEndedAt.timeIntervalSince(editedCreatedAt)))
        
        viewModel.updateMeetingMetadata(
            title: title,
            location: location,
            createdAt: editedCreatedAt,
            attendees: attendeesStr,
            duration: duration
        )
    }
    
    private func addAttendee() {
        let name = newAttendeeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        var list = editedAttendeesList
        if !list.contains(name) {
            list.append(name)
            let newStr = list.joined(separator: " ")
            
            // 保存写入数据库
            viewModel.updateMeetingMetadata(
                title: editedTitle.isEmpty ? (viewModel.currentMeeting?.title ?? "") : editedTitle,
                location: editedLocation.isEmpty ? nil : editedLocation,
                createdAt: editedCreatedAt,
                attendees: newStr
            )
        }
        newAttendeeName = ""
    }
    
    private func removeAttendee(_ name: String) {
        var list = editedAttendeesList
        list.removeAll { $0 == name }
        let newStr = list.joined(separator: " ")
        
        // 保存写入数据库
        viewModel.updateMeetingMetadata(
            title: editedTitle.isEmpty ? (viewModel.currentMeeting?.title ?? "") : editedTitle,
            location: editedLocation.isEmpty ? nil : editedLocation,
            createdAt: editedCreatedAt,
            attendees: newStr
        )
    }

    private func formatCreatedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - 音频播放控制面板
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
                            let url = meeting.localAudioURL
                            
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

    private func playSegment(_ segment: TranscriptSegment) {
        if let meeting = viewModel.currentMeeting {
            let url = meeting.localAudioURL
            
            // 如果还没初始化过播放器，则先初始化
            if !viewModel.audioPlayer.hasPlayer {
                viewModel.audioPlayer.startPlaying(url: url)
            }
        }
        
        // 进度跳转
        viewModel.audioPlayer.seek(to: segment.startTime)
        
        // 如果当前未播放，则自动播放
        if !viewModel.audioPlayer.isPlaying {
            viewModel.audioPlayer.resume()
        }
    }
}
