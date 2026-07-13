import SwiftUI

/// 共享的会议信息编辑侧边栏（RecordingView / ReviewingView 共用）
struct MeetingInfoSidebar: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(DatabaseManager.self) private var databaseManager

    @State private var editedTitle = ""
    @State private var editedLocation = ""
    @State private var editedCreatedAt = Date()
    @State private var editedEndedAt = Date()
    @State private var newAttendeeName = ""
    @State private var showDatePickerPopover = false
    @State private var showEndDatePickerPopover = false
    @State private var selectedHighlightSpeaker: String? = nil

    var showSpeakerSections: Bool = true

    private var editedAttendeesList: [String] {
        let s = viewModel.currentMeeting?.attendees ?? ""
        if s.isEmpty { return [] }
        return s.split(separator: " ").map(String.init)
    }

    private var speakerStats: [(speaker: String, count: Int, duration: Double)] {
        var stats = [String: (count: Int, duration: Double)]()
        for segment in viewModel.transcriptSegments.filter({ $0.isFinal }) {
            let current = stats[segment.speakerLabel] ?? (0, 0.0)
            let segDur = max(0, segment.endTime - segment.startTime)
            stats[segment.speakerLabel] = (current.0 + 1, current.1 + segDur)
        }
        return stats.map { ($0.key, $0.value.count, $0.value.duration) }.sorted { $0.2 > $1.2 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("会议属性")
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("会议主题")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("输入会议主题", text: $editedTitle)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { saveMetadata() }
                    }

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
                                Text(formatDate(editedCreatedAt))
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
                                .onChange(of: editedCreatedAt) { _, _ in saveMetadata() }
                        }
                    }

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
                                Text(formatDate(editedEndedAt))
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
                                .onChange(of: editedEndedAt) { _, _ in saveMetadata() }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("地点")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("会议地点", text: $editedLocation)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { saveMetadata() }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("参会人")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let list = editedAttendeesList
                        if !list.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(list, id: \.self) { person in
                                    HStack(spacing: 4) {
                                        Text(person).font(.subheadline)
                                        Button {
                                            removeAttendee(person)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.purple.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.bottom, 4)
                        }
                        HStack {
                            TextField("添加人...", text: $newAttendeeName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { addAttendee() }
                            Button { addAttendee() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.purple)
                            }
                            .buttonStyle(.plain)
                            .disabled(newAttendeeName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if showSpeakerSections {
                        speakerMatchingSection
                        speakerStatsSection
                    }
                }
                .padding(.trailing, 2)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .onAppear { loadMetadata() }
        .onChange(of: viewModel.currentMeeting) { _, _ in loadMetadata() }
    }

    // MARK: - 说话人匹配

    private var speakerMatchingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 4)
            HStack {
                Text("说话人匹配")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink(destination: GlobalSpeakerListView()) {
                    HStack(spacing: 2) {
                        Image(systemName: "person.3.sequence.fill")
                        Text("字典")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
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
                                Text(editedAttendeesList.contains(speaker) ? "已绑定" : "选择")
                                    .foregroundStyle(editedAttendeesList.contains(speaker) ? .green : .secondary)
                                Image(systemName: "chevron.down").font(.system(size: 10))
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 8).padding(.vertical, 4)
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

    // MARK: - 声纹发言统计

    private var speakerStatsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 4)
            Text("发言统计")
                .font(.caption)
                .foregroundStyle(.secondary)
            let stats = speakerStats
            if stats.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(stats, id: \.speaker) { item in
                    Button {
                        selectedHighlightSpeaker = (selectedHighlightSpeaker == item.speaker) ? nil : item.speaker
                    } label: {
                        HStack {
                            Text(item.speaker)
                                .font(.subheadline)
                                .fontWeight(selectedHighlightSpeaker == item.speaker ? .bold : .regular)
                                .foregroundStyle(selectedHighlightSpeaker == item.speaker ? .purple : .primary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)句 | \(String(format: "%.1f", item.duration))s")
                                .font(.caption).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedHighlightSpeaker == item.speaker ? Color.purple.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 辅助方法

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
            title: title, location: location, createdAt: editedCreatedAt,
            attendees: attendeesStr, duration: duration
        )
    }

    private func addAttendee() {
        let name = newAttendeeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var list = editedAttendeesList
        if !list.contains(name) {
            list.append(name)
            saveMetadata()
        }
        newAttendeeName = ""
    }

    private func removeAttendee(_ name: String) {
        saveMetadata()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
