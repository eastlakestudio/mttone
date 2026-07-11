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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建会议")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                    }

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

                    Toggle("延续上一次会议", isOn: $viewModel.shouldExtendLastMeeting)
                        .font(.subheadline)
                }
                .padding()
            }

            Divider()

            VStack(spacing: 12) {
                Picker("音频来源", selection: $viewModel.recordingMode) {
                    Text("开始录音").tag(RecordingViewModel.RecordingMode.liveRecording)
                    Text("导入文件").tag(RecordingViewModel.RecordingMode.importFile)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

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
                            viewModel.shouldTriggerImport = true
                            dismiss()
                        }
                    } label: {
                        Label("开始", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, idealWidth: 420)
        .onAppear {
            locationSuggestions = databaseManager.fetchDistinctLocations()
            speakerSuggestions = databaseManager.fetchDistinctSpeakers()
            if !viewModel.formAttendees.isEmpty {
                attendees = viewModel.formAttendees
                    .split(separator: " ")
                    .map(String.init)
                    .filter { !$0.isEmpty }
            }
        }
        .onDisappear {
            viewModel.formAttendees = attendees.joined(separator: " ")
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
