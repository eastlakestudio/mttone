import SwiftUI

struct NewMeetingSheet: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(DatabaseManager.self) private var databaseManager

    @State private var locationSuggestions: [String] = []
    @State private var showLocationSuggestions = false
    @State private var attendeeText = ""
    @State private var attendees: [String] = []
    @State private var speakerSuggestions: [String] = []
    @State private var isImporting = false
    @State private var recentMeetings: [Meeting] = []
    @State private var tempSelectedAudioURL: URL? = nil
    @State private var originalAudioFileName: String = ""
    @State private var showDatePickerPopover = false

    private var formattedFormDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: viewModel.formCreatedAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建会议")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // 1. 会议主题 (独占一行)
                VStack(alignment: .leading, spacing: 6) {
                    Text("会议主题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("输入会议主题", text: $viewModel.formTitle)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 2. 开始时间 与 会议地点 (共用一行)
                HStack(alignment: .top, spacing: 16) {
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
                                Text(formattedFormDate)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDatePickerPopover) {
                            VStack {
                                DatePicker("", selection: $viewModel.formCreatedAt, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                            }
                            .padding()
                            .frame(width: 280, height: 320)
                        }
                    }
                    .frame(width: 180)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("会议地点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("输入地点", text: $viewModel.formLocation)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: viewModel.formLocation) { _, _ in
                                showLocationSuggestions = !viewModel.formLocation.isEmpty
                            }
                            .onSubmit { showLocationSuggestions = false }
                    }
                }

                if showLocationSuggestions && !viewModel.formLocation.isEmpty {
                    let filtered = locationSuggestions.filter {
                        $0.lowercased().contains(viewModel.formLocation.lowercased())
                    }
                    if !filtered.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filtered.prefix(8), id: \.self) { loc in
                                    Button {
                                        viewModel.formLocation = loc
                                        showLocationSuggestions = false
                                    } label: {
                                        Text(loc)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(.quaternary.opacity(0.5))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }

                // 3. 参会人
                VStack(alignment: .leading, spacing: 6) {
                    Text("参会人")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !attendees.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(attendees, id: \.self) { person in
                                HStack(spacing: 4) {
                                    Text(person)
                                        .font(.caption)
                                    Button {
                                        attendees.removeAll { $0 == person }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.purple.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }

                    HStack {
                        TextField("添加参会人", text: $attendeeText)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onSubmit { addAttendee() }

                        if !attendeeText.isEmpty {
                            Button { addAttendee() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.purple)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !attendeeText.isEmpty {
                        let filtered = speakerSuggestions.filter {
                            $0.lowercased().contains(attendeeText.lowercased())
                                && !attendees.contains($0)
                        }
                        if !filtered.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filtered.prefix(8), id: \.self) { name in
                                        Button {
                                            attendees.append(name)
                                            attendeeText = ""
                                        } label: {
                                            Text(name)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(.quaternary.opacity(0.5))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }
                }

                // 4. 音频来源
                VStack(alignment: .leading, spacing: 6) {
                    Text("音频来源")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Button {
                            viewModel.recordingMode = .liveRecording
                        } label: {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("实时录音")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.recordingMode == .liveRecording ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
                            .foregroundStyle(viewModel.recordingMode == .liveRecording ? Color.purple : Color.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.recordingMode == .liveRecording ? Color.purple : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            print("[NewMeetingSheet] Audio File Button clicked.")
                            if viewModel.recordingMode != .importFile {
                                viewModel.recordingMode = .importFile
                            } else {
                                print("[NewMeetingSheet] Already in importFile mode, triggering isImporting = true")
                                isImporting = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill")
                                Text(originalAudioFileName.isEmpty ? "音频文件" : "音频文件: \(originalAudioFileName)")
                                    .lineLimit(1)
                                if !originalAudioFileName.isEmpty {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.recordingMode == .importFile ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
                            .foregroundStyle(viewModel.recordingMode == .importFile ? Color.purple : Color.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.recordingMode == .importFile ? Color.purple : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 5. 延续历史会议
                HStack(spacing: 16) {
                    Toggle("延续历史会议", isOn: $viewModel.shouldExtendLastMeeting)
                        .font(.subheadline)
                        .frame(width: 180, alignment: .leading)

                    if viewModel.shouldExtendLastMeeting && !recentMeetings.isEmpty {
                        Picker("", selection: $viewModel.selectedParentMeetingId) {
                            ForEach(recentMeetings, id: \.id) { meeting in
                                Text(meetingPickerTitle(for: meeting)).tag(String?.some(meeting.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()

            Divider()

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Spacer()

                Button {
                    if viewModel.recordingMode == .liveRecording {
                        Task {
                            await viewModel.startRecording()
                        }
                    } else {
                        if let tempURL = tempSelectedAudioURL {
                            Task {
                                viewModel.formAttendees = attendees.joined(separator: " ")
                                await viewModel.importAudioFile(
                                    from: tempURL,
                                    title: viewModel.formTitle.isEmpty ? nil : viewModel.formTitle,
                                    location: viewModel.formLocation.isEmpty ? nil : viewModel.formLocation
                                )
                                try? FileManager.default.removeItem(at: tempURL)
                                tempSelectedAudioURL = nil
                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        }
                    }
                } label: {
                    Label("开始", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)
                .disabled(viewModel.recordingMode == .importFile && tempSelectedAudioURL == nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 440, idealWidth: 480)
        .onChange(of: viewModel.recordingMode) { _, newMode in
            print("[NewMeetingSheet] recordingMode changed to: \(newMode)")
            if newMode == .importFile {
                print("[NewMeetingSheet] Triggering isImporting = true via onChange")
                isImporting = true
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            print("[NewMeetingSheet] fileImporter callback triggered. Result: \(result)")
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    print("[NewMeetingSheet] No URL found in success result.")
                    return
                }
                print("[NewMeetingSheet] Selected file: \(url.path)")
                let gained = url.startAccessingSecurityScopedResource()
                defer {
                    if gained {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("temp_import_\(UUID().uuidString).\(url.pathExtension)")
                try? FileManager.default.removeItem(at: tempURL)
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    tempSelectedAudioURL = tempURL
                    originalAudioFileName = url.lastPathComponent
                    print("[NewMeetingSheet] Successfully copied to temp location: \(tempURL.path)")
                } catch {
                    print("[NewMeetingSheet] Copy temp file failed: \(error)")
                }
            case .failure(let error):
                print("[NewMeetingSheet] File import failed: \(error.localizedDescription)")
            }
        }
        .onAppear {
            locationSuggestions = databaseManager.fetchDistinctLocations()
            speakerSuggestions = databaseManager.fetchDistinctSpeakers()
            if !viewModel.formAttendees.isEmpty {
                attendees = viewModel.formAttendees
                    .split(separator: " ")
                    .map(String.init)
                    .filter { !$0.isEmpty }
            }
            recentMeetings = databaseManager.fetchAllMeetings()
            if viewModel.selectedParentMeetingId == nil {
                viewModel.selectedParentMeetingId = recentMeetings.first?.id
            }
        }
        .onDisappear {
            viewModel.formAttendees = attendees.joined(separator: " ")
            if let tempURL = tempSelectedAudioURL {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    private func addAttendee() {
        let trimmed = attendeeText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !attendees.contains(trimmed) {
            attendees.append(trimmed)
        }
        attendeeText = ""
    }

    private func meetingPickerTitle(for meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let start = formatter.string(from: meeting.createdAt)
        let end = formatter.string(from: meeting.createdAt.addingTimeInterval(Double(meeting.duration)))
        return "\(meeting.title) (\(start)-\(end))"
    }
}

// MARK: - 流式标签布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = y + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
