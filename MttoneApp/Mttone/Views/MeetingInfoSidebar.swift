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
    @Binding var filterSpeaker: String?
    @Binding var attendeesString: String
    @State private var renamePerson = ""
    @State private var showRenameAttendeePopover = false
    @State private var renameTarget = ""
    @State private var showContactPicker = false
    @State private var attendeeSearchText = ""
    @State private var showNewContactSheet = false
    @State private var showMultiSelectPopover = false

    var showSpeakerSections: Bool = true

    private var editedAttendeesList: [String] {
        if attendeesString.isEmpty { return [] }
        return attendeesString.split(separator: " ").map(String.init)
    }

    private var speakerStats: [(speaker: String, count: Int, duration: Double)] {
        var stats = [String: (count: Int, duration: Double)]()
        for segment in viewModel.transcriptSegments.filter({ $0.isFinal }) {
            let current = stats[segment.speakerLabel] ?? (0, 0.0)
            let segDur = max(0, segment.endTime - segment.startTime)
            stats[segment.speakerLabel] = (current.0 + 1, current.1 + segDur)
        }
        for person in editedAttendeesList {
            if stats[person] == nil { stats[person] = (0, 0.0) }
        }
        return stats.map { ($0.key, $0.value.count, $0.value.duration) }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("会议属性").font(.headline).padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleField
                    startTimeField
                    endTimeField
                    locationField
                    attendeeField
                    if showSpeakerSections {
                        speakerMatchingSection
                        speakerStatsSection
                    }
                }.padding(.trailing, 2)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .onAppear { loadMetadata() }
        .onChange(of: viewModel.currentMeeting) { _, _ in loadMetadata() }
        .popover(isPresented: $showRenameAttendeePopover) {
            VStack(spacing: 8) {
                Text("重命名参会人").font(.caption).foregroundStyle(.secondary)
                TextField("新名称", text: $renamePerson).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer(); Button("取消") { showRenameAttendeePopover = false }
                    Button("确定") {
                        let newName = renamePerson.trimmingCharacters(in: .whitespaces)
                        if !newName.isEmpty && newName != renameTarget {
                            viewModel.globalRenameSpeaker(oldName: renameTarget, newName: newName)
                            var list = editedAttendeesList
                            if let idx = list.firstIndex(of: renameTarget) { list[idx] = newName }
                            attendeesString = list.joined(separator: " ")
                        }
                        showRenameAttendeePopover = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding().frame(width: 220)
        }
    }

    // MARK: - Fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("会议主题").font(.caption).foregroundStyle(.secondary)
            TextField("输入会议主题", text: $editedTitle).textFieldStyle(.roundedBorder).onSubmit { saveMetadata() }
        }
    }

    private var startTimeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("开始时间").font(.caption).foregroundStyle(.secondary)
            Button { showDatePickerPopover = true } label: {
                HStack {
                    Image(systemName: "calendar").foregroundStyle(.purple)
                    Text(formatDate(editedCreatedAt)).font(.subheadline); Spacer()
                }.padding(8).background(.quaternary.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
            .popover(isPresented: $showDatePickerPopover) {
                DatePicker("", selection: $editedCreatedAt, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical).labelsHidden().padding().frame(width: 280, height: 320)
                    .onChange(of: editedCreatedAt) { _, _ in saveMetadata() }
            }
        }
    }

    private var endTimeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("结束时间").font(.caption).foregroundStyle(.secondary)
            Button { showEndDatePickerPopover = true } label: {
                HStack {
                    Image(systemName: "calendar").foregroundStyle(.purple)
                    Text(formatDate(editedEndedAt)).font(.subheadline); Spacer()
                }.padding(8).background(.quaternary.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain)
            .popover(isPresented: $showEndDatePickerPopover) {
                DatePicker("", selection: $editedEndedAt, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical).labelsHidden().padding().frame(width: 280, height: 320)
                    .onChange(of: editedEndedAt) { _, _ in saveMetadata() }
            }
        }
    }

    private var locationField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("地点").font(.caption).foregroundStyle(.secondary)
            TextField("会议地点", text: $editedLocation).textFieldStyle(.roundedBorder).onSubmit { saveMetadata() }
        }
    }

    private var attendeeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("参会人").font(.caption).foregroundStyle(.secondary)
            let list = editedAttendeesList
            if !list.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(list, id: \.self) { person in
                        HStack(spacing: 4) {
                            Text(person).font(.subheadline)
                            Button { removeAttendee(person) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.purple.opacity(0.1)).clipShape(Capsule())
                    }
                }.padding(.bottom, 4)
            }

            // 搜索输入 → 筛选结果
            HStack {
                TextField("搜索人员...", text: $attendeeSearchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        let trimmed = attendeeSearchText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            let matches = filteredContacts
                            if let first = matches.first {
                                addAttendeeByName(first.name)
                            }
                        }
                    }
                    .onChange(of: attendeeSearchText) { _, _ in }
                Button { showNewContactSheet = true } label: {
                    Image(systemName: "person.badge.plus").foregroundStyle(.purple)
                }.buttonStyle(.plain).help("新建人员")

                Button { showMultiSelectPopover = true } label: {
                    Image(systemName: "list.bullet.rectangle").foregroundStyle(.purple)
                }.buttonStyle(.plain).help("从全局人员库多选")
                .popover(isPresented: $showMultiSelectPopover) {
                    MultiSelectContactPicker(
                        selectedNames: Set(editedAttendeesList),
                        onConfirm: { names in
                            let current = editedAttendeesList
                            var all = current
                            for name in names where !current.contains(name) {
                                all.append(name)
                            }
                            saveMetadata(updatedAttendees: all.joined(separator: " "))
                            showMultiSelectPopover = false
                        }
                    )
                }
            }

            // 搜索结果下拉
            if !attendeeSearchText.isEmpty {
                let matches = filteredContacts
                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(matches.prefix(6), id: \.id) { contact in
                            Button {
                                addAttendeeByName(contact.name)
                                attendeeSearchText = ""
                            } label: {
                                HStack {
                                    Text(contact.name).font(.subheadline)
                                    if let c = contact.company { Text("· \(c)").font(.caption).foregroundStyle(.secondary) }
                                    Spacer()
                                    if let r = contact.role { Text(r).font(.caption2).foregroundStyle(.purple) }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if contact.id != matches.prefix(6).last?.id { Divider() }
                        }
                    }
                    .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .sheet(isPresented: $showNewContactSheet) {
            NewContactSheet { contact in
                try? databaseManager.saveContact(contact)
                addAttendeeByName(contact.name)
                showNewContactSheet = false
            } onCancel: { showNewContactSheet = false }
        }
    }

    private var filteredContacts: [Contact] {
        let text = attendeeSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if text.isEmpty { return [] }
        let all = databaseManager.fetchAllContacts()
        return all.filter {
            $0.name.lowercased().contains(text)
            || ($0.company?.lowercased().contains(text) ?? false)
            || ($0.role?.lowercased().contains(text) ?? false)
        }
    }

    private func addAttendeeByName(_ name: String) {
        var list = editedAttendeesList
        if !list.contains(name) { list.append(name) }
        saveMetadata(updatedAttendees: list.joined(separator: " "))
    }

    // MARK: - 说话人匹配

    private var speakerMatchingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 4)
            HStack {
                Text("说话人匹配").font(.caption).foregroundStyle(.secondary)
                Spacer()
                NavigationLink(destination: PersonnelManagementView()) {
                    HStack(spacing: 2) {
                        Image(systemName: "person.3.sequence.fill"); Text("字典")
                    }
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.purple.opacity(0.1)).foregroundStyle(.purple).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
            let unmatched = viewModel.uniqueSpeakers.filter { !editedAttendeesList.contains($0) }
            if unmatched.isEmpty {
                Text("暂无未匹配说话人").font(.subheadline).foregroundStyle(.tertiary)
            } else {
                ForEach(unmatched, id: \.self) { speaker in
                    HStack {
                        Image(systemName: "circle").font(.caption).foregroundStyle(.tertiary)
                        Text(speaker).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Menu {
                            Section("绑定到参会人") {
                                ForEach(editedAttendeesList, id: \.self) { person in
                                    Button(person) {
                                        viewModel.globalRenameSpeaker(oldName: speaker, newName: person)
                                    }
                                }
                            }
                            if editedAttendeesList.isEmpty {
                                Text("暂无参会人").font(.caption).foregroundStyle(.tertiary)
                            }
                        } label: {
                            Text("绑定").font(.caption).foregroundStyle(.purple)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.purple.opacity(0.1)).clipShape(Capsule())
                        }
                        .menuStyle(.borderlessButton).buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(filterSpeaker == speaker ? Color.purple.opacity(0.12) : Color.clear)
                    )
                }
            }
        }
    }

    // MARK: - 发言统计

    private var speakerStatsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 4)
            Text("发言统计").font(.caption).foregroundStyle(.secondary)
            let stats = speakerStats
            if stats.isEmpty {
                Text("暂无数据").font(.subheadline).foregroundStyle(.tertiary)
            } else {
                ForEach(stats, id: \.speaker) { item in
                    HStack {
                        Button {
                            filterSpeaker = (filterSpeaker == item.speaker) ? nil : item.speaker
                        } label: {
                            HStack {
                                Text(item.speaker)
                                    .font(.subheadline).lineLimit(1)
                                    .fontWeight(filterSpeaker == item.speaker ? .bold : .regular)
                                    .foregroundStyle(filterSpeaker == item.speaker ? .purple : .primary)
                                Spacer()
                                Text("\(item.count)句 | \(String(format: "%.1f", item.duration))s")
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(filterSpeaker == item.speaker ? Color.purple.opacity(0.15) : Color.clear)
                            )
                        }.buttonStyle(.plain)

                        Menu {
                            if !editedAttendeesList.isEmpty {
                                Section("分配到参会人") {
                                    ForEach(editedAttendeesList.filter { $0 != item.speaker }, id: \.self) { person in
                                        Button(person) {
                                            viewModel.globalRenameSpeaker(oldName: item.speaker, newName: person)
                                        }
                                    }
                                }
                            }
                            Button("重命名") {
                                renameTarget = item.speaker; renamePerson = item.speaker
                                showRenameAttendeePopover = true
                            }
                            if editedAttendeesList.contains(item.speaker) {
                                Button("从参会人中移除", role: .destructive) {
                                    removeAttendee(item.speaker)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.caption).foregroundStyle(.tertiary)
                        }
                        .menuStyle(.borderlessButton).buttonStyle(.plain).frame(width: 16)
                    }
                }
            }
        }
    }

    // MARK: - 辅助

    private func loadMetadata() {
        if let meeting = viewModel.currentMeeting {
            editedTitle = meeting.title
            editedLocation = meeting.location ?? ""
            editedCreatedAt = meeting.createdAt
            editedEndedAt = meeting.createdAt.addingTimeInterval(TimeInterval(meeting.duration))
        }
    }

    private func saveMetadata(updatedAttendees: String? = nil) {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let loc = editedLocation.trimmingCharacters(in: .whitespaces)
        let location = loc.isEmpty ? nil : loc
        let attendeesStr = updatedAttendees ?? attendeesString
        // 新增参会人时同步创建全局联系人
        if let updated = updatedAttendees {
            let before = Set(attendeesString.split(separator: " ").map(String.init))
            let after = Set(updated.split(separator: " ").map(String.init))
            for name in after.subtracting(before) where databaseManager.fetchContact(byName: name) == nil {
                try? databaseManager.saveContact(Contact.create(name: name))
            }
        }
        let duration = max(0, Int(editedEndedAt.timeIntervalSince(editedCreatedAt)))
        if updatedAttendees != nil { attendeesString = attendeesStr }
        viewModel.updateMeetingMetadata(
            title: title, location: location, createdAt: editedCreatedAt,
            attendees: attendeesStr, duration: duration
        )
    }

    private func addAttendee() {
        let name = newAttendeeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var list = editedAttendeesList
        if !list.contains(name) { list.append(name); saveMetadata(updatedAttendees: list.joined(separator: " ")) }
        newAttendeeName = ""
    }

    private func removeAttendee(_ name: String) {
        var list = editedAttendeesList
        list.removeAll { $0 == name }
        saveMetadata(updatedAttendees: list.joined(separator: " "))
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: date)
    }
}

struct NewContactSheet: View {
    var onSave: (Contact) -> Void
    var onCancel: () -> Void
    @State private var name = ""
    @State private var role = ""
    @State private var company = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("新建人员").font(.headline)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("人名").font(.caption).foregroundStyle(.secondary)
                    TextField("姓名（必填）", text: $name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("角色").font(.caption).foregroundStyle(.secondary)
                    TextField("如：项目经理、开发工程师", text: $role).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("组织").font(.caption).foregroundStyle(.secondary)
                    TextField("如：阿里巴巴、腾讯", text: $company).textFieldStyle(.roundedBorder)
                }
            }
            HStack(spacing: 12) {
                Button("取消") { onCancel() }.controlSize(.large)
                Spacer()
                Button("创建") {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    let contact = Contact(
                        id: UUID().uuidString,
                        name: n,
                        role: role.trimmingCharacters(in: .whitespaces).isEmpty ? nil : role.trimmingCharacters(in: .whitespaces),
                        company: company.trimmingCharacters(in: .whitespaces).isEmpty ? nil : company.trimmingCharacters(in: .whitespaces),
                        avatarUrl: nil, createdAt: Date(), updatedAt: Date()
                    )
                    onSave(contact)
                }
                .buttonStyle(.borderedProminent).tint(.purple).controlSize(.large)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding().frame(width: 360)
    }
}

struct MultiSelectContactPicker: View {
    @Environment(DatabaseManager.self) private var db
    @State private var contacts: [Contact] = []
    @State private var selectedNames: Set<String>
    @State private var searchText = ""
    @State private var showNewContactInPicker = false
    let onConfirm: (Set<String>) -> Void

    init(selectedNames: Set<String>, onConfirm: @escaping (Set<String>) -> Void) {
        self._selectedNames = State(initialValue: selectedNames)
        self.onConfirm = onConfirm
    }

    private var filteredContacts: [Contact] {
        let text = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if text.isEmpty { return contacts }
        return contacts.filter {
            $0.name.lowercased().contains(text)
            || ($0.company?.lowercased().contains(text) ?? false)
            || ($0.role?.lowercased().contains(text) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择参会人").font(.headline)
                Spacer()
            }.padding()

            TextField("搜索...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Divider().padding(.vertical, 4)

            if filteredContacts.isEmpty {
                Text("无匹配人员").font(.subheadline).foregroundStyle(.secondary).padding()
            } else {
                List(filteredContacts, id: \.id) { contact in
                    Button {
                        if selectedNames.contains(contact.name) {
                            selectedNames.remove(contact.name)
                        } else {
                            selectedNames.insert(contact.name)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedNames.contains(contact.name) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedNames.contains(contact.name) ? .purple : .secondary)
                            Text(contact.name).font(.subheadline)
                            if let company = contact.company {
                                Text(company).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let role = contact.role {
                                Text(role).font(.caption2).foregroundStyle(.purple)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            HStack(spacing: 12) {
                Button { showNewContactInPicker = true } label: {
                    Label("新建", systemImage: "person.badge.plus").font(.caption)
                }.buttonStyle(.borderless)
                Text("已选 \(selectedNames.count) 人").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("取消") { onConfirm([]) }.buttonStyle(.borderless)
                Button("确认") { onConfirm(selectedNames) }
                    .buttonStyle(.borderedProminent).tint(.purple).controlSize(.small)
            }.padding()
        }
        .frame(width: 300, height: 400)
        .onAppear { contacts = db.fetchAllContacts() }
        .sheet(isPresented: $showNewContactInPicker) {
            NewContactSheet(
                onSave: { contact in
                    try? db.saveContact(contact)
                    selectedNames.insert(contact.name)
                    contacts = db.fetchAllContacts()
                    showNewContactInPicker = false
                },
                onCancel: { showNewContactInPicker = false }
            )
        }
    }
}
