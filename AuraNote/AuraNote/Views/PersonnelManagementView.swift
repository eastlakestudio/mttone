import SwiftUI

struct PersonGroupedClips: Identifiable {
    let id = UUID()
    let meeting: Meeting
    let clips: [SpeechClip]
}

struct PersonnelManagementView: View {
    @Environment(DatabaseManager.self) private var db
    @State private var contacts: [Contact] = []
    @State private var showAddSheet = false
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: Contact?
    @State private var editContact: Contact?
    @State private var selectedContact: Contact?
    @State private var groupedClips: [PersonGroupedClips] = []
    @State private var collapsedGroups: Set<UUID> = []   // 折叠的会议分组
    @State private var pendingReassignClip: SpeechClip?   // 待分配片段（新增联系人后自动绑定）
    @State private var editingAttrName = ""
    @State private var editingAttrRole = ""
    @State private var editingAttrCompany = ""
    @State private var isDirty = false
    @State private var lastLoadedContactId: String?
    @State private var clipPlayer = AudioPlayer()

    // 发言删除确认
    @State private var showDeleteClipConfirm = false
    @State private var deleteClipTarget: SpeechClip?
    @State private var showDeleteMeetingClipsConfirm = false
    @State private var deleteMeetingClipsTarget: PersonGroupedClips?
    @State private var showClearAllConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            // 左列：人员列表 + 属性
            leftColumn
                .frame(width: 280)

            Divider()

            // 右列：发言记录
            rightColumn
                .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { contacts = db.fetchAllContacts() }
        .sheet(isPresented: $showAddSheet) {
            ContactEditView(onSave: { contact in
                try? db.saveContact(contact)
                contacts = db.fetchAllContacts()
                // 如果有待分配的片段，自动绑定到新创建的联系人
                if let clip = pendingReassignClip {
                    reassignClip(clip, to: contact)
                    pendingReassignClip = nil
                }
                showAddSheet = false
            }, onCancel: {
                pendingReassignClip = nil
                showAddSheet = false
            })
        }
        .sheet(item: $editContact) { contact in
            ContactEditView(existing: contact, onSave: { updated in
                try? db.saveContact(updated)
                contacts = db.fetchAllContacts()
                editContact = nil
            }, onCancel: { editContact = nil })
        }
        .alert(loc("confirm_delete_person"), isPresented: $showDeleteConfirm) {
            Button(loc("cancel"), role: .cancel) { deleteTarget = nil }
            Button(loc("delete"), role: .destructive) {
                if let contact = deleteTarget {
                    try? db.deleteContact(id: contact.id)
                    contacts = db.fetchAllContacts()
                    if selectedContact?.id == contact.id { selectedContact = nil }
                    deleteTarget = nil
                }
            }
        } message: {
            if let contact = deleteTarget {
                Text(String(format: loc("confirm_delete_person_msg"), contact.name))
            }
        }
        .alert(loc("delete_speech_clip"), isPresented: $showDeleteClipConfirm) {
            Button(loc("cancel"), role: .cancel) { deleteClipTarget = nil }
            Button(loc("delete"), role: .destructive) {
                if let clip = deleteClipTarget {
                    try? db.deleteSpeechClip(id: clip.id)
                    refreshClips()
                    deleteClipTarget = nil
                }
            }
        } message: {
            Text(loc("delete_speech_clip_msg"))
        }
        .alert(loc("delete_meeting_clips"), isPresented: $showDeleteMeetingClipsConfirm) {
            Button(loc("cancel"), role: .cancel) { deleteMeetingClipsTarget = nil }
            Button(loc("delete"), role: .destructive) {
                if let group = deleteMeetingClipsTarget {
                    try? db.deleteClips(forMeeting: group.meeting.id)
                    refreshClips()
                    deleteMeetingClipsTarget = nil
                }
            }
        } message: {
            if let group = deleteMeetingClipsTarget {
                Text(String(format: loc("delete_meeting_clips_msg"), group.meeting.title, group.clips.count))
            }
        }
        .alert(loc("clear_all_clips"), isPresented: $showClearAllConfirm) {
            Button(loc("cancel"), role: .cancel) { }
            Button(loc("delete"), role: .destructive) {
                try? db.clearAllSpeechClips()
                refreshClips()
            }
        } message: {
            Text(loc("clear_all_clips_msg"))
        }
    }

    // MARK: - 左列

    private var leftColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc("personnel_list")).font(.headline)
                Spacer()
                Button { showAddSheet = true } label: {
                    Image(systemName: "person.badge.plus").foregroundStyle(.purple)
                }.buttonStyle(.plain).help(loc("add_person"))
            }.padding()

            Divider()

            if contacts.isEmpty {
                VStack(spacing: 8) {
                    Text(loc("no_personnel")).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxHeight: .infinity)
            } else {
                List(contacts, id: \.id) { contact in
                    Button {
                        selectedContact = contact
                        editingAttrName = contact.name
                        editingAttrRole = contact.role ?? ""
                        editingAttrCompany = contact.company ?? ""
                        isDirty = false
                        let items = db.fetchSpeechClipsGroupedByMeeting(forContact: contact.id)
                        groupedClips = items.map { PersonGroupedClips(meeting: $0.meeting, clips: $0.clips) }
                        collapsedGroups = Set(groupedClips.map { $0.id })  // 默认全部折叠
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(personColor(contact.name))
                                .frame(width: 24, height: 24)
                                .overlay(Text(String(contact.name.prefix(1))).font(.caption2).foregroundStyle(.white))
                            Text(contact.name).font(.subheadline)
                                .foregroundStyle(selectedContact?.id == contact.id ? .purple : .primary)
                            Spacer()
                            if let company = contact.company {
                                Text(company).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editContact = contact } label: {
                            Label(loc("edit"), systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteTarget = contact
                            showDeleteConfirm = true
                        } label: {
                            Label(loc("delete"), systemImage: "trash")
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            // 属性面板
            if let contact = selectedContact {
                Divider()
                attributePanel(contact)
            }
        }
        .background(.regularMaterial)
    }

    private func attributePanel(_ contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(loc("person_attributes")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                // 预留固定高度按钮区域，避免面板抖动
                ZStack {
                    if isDirty {
                        Button(loc("save")) {
                            let updated = Contact(
                                id: contact.id,
                                name: editingAttrName.trimmingCharacters(in: .whitespaces),
                                role: editingAttrRole.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editingAttrRole.trimmingCharacters(in: .whitespaces),
                                company: editingAttrCompany.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editingAttrCompany.trimmingCharacters(in: .whitespaces),
                                avatarUrl: contact.avatarUrl,
                                createdAt: contact.createdAt,
                                updatedAt: Date()
                            )
                            try? db.saveContact(updated)
                            selectedContact = updated
                            contacts = db.fetchAllContacts()
                            isDirty = false
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)
                        .disabled(editingAttrName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .frame(height: 22)
            }
            VStack(spacing: 6) {
                HStack {
                    Text(loc("name")).font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                    TextField("", text: $editingAttrName)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .onChange(of: editingAttrName) { _, _ in setDirtyIfChanged(contact) }
                    }
                    HStack {
                        Text(loc("role")).font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                        TextField("", text: $editingAttrRole)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                            .onChange(of: editingAttrRole) { _, _ in setDirtyIfChanged(contact) }
                    }
                    HStack {
                        Text(loc("org")).font(.caption).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                        TextField("", text: $editingAttrCompany)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                            .onChange(of: editingAttrCompany) { _, _ in setDirtyIfChanged(contact) }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - 右列

    private var rightColumn: some View {
        VStack(spacing: 0) {
            if let contact = selectedContact {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.headline)
                        if let role = contact.role {
                            Text(role).font(.caption).foregroundStyle(.purple)
                        }
                    }
                    Spacer()
                    Text(String(format: loc("speech_count_fmt"), groupedClips.reduce(0) { $0 + $1.clips.count }, groupedClips.count))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            } else {
                // 未选人时显示统计信息
                VStack(spacing: 16) {
                    HStack {
                        Text(loc("personnel_overview")).font(.headline)
                        Spacer()
                    }
                    
                    let total = contacts.count
                    let companies = companyStats
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text(loc("total")).font(.title2).foregroundStyle(.secondary)
                            Text("\(total)").font(.largeTitle).fontWeight(.bold).foregroundStyle(.purple)
                            Text(loc("people_unit")).font(.title2).foregroundStyle(.secondary)
                        }
                        
                        if !companies.isEmpty {
                            Divider()
                            VStack(spacing: 8) {
                                ForEach(companies.sorted(by: { $0.value > $1.value }).prefix(8), id: \.key) { company, count in
                                    HStack {
                                        Image(systemName: "building.2.fill").font(.callout).foregroundStyle(.blue)
                                        Text(company).font(.callout).lineLimit(1).frame(width: 120, alignment: .leading)
                                        Spacer()
                                        Text(String(format: loc("people_count_fmt"), count)).font(.title3).fontWeight(.medium).foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding()
            }

            Divider()

            if groupedClips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform").font(.largeTitle).foregroundStyle(.quaternary)
                    Text(loc("no_speech_records")).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxHeight: .infinity)
            } else {
                // 全部清空按钮
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        showClearAllConfirm = true
                    } label: {
                        Label(loc("clear_all_clips"), systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedClips) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                // 会议标题头（可点击折叠）
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if collapsedGroups.contains(group.id) {
                                            collapsedGroups.remove(group.id)
                                        } else {
                                            collapsedGroups.insert(group.id)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: collapsedGroups.contains(group.id) ? "chevron.right" : "chevron.down")
                                            .font(.caption).foregroundStyle(.secondary)
                                            .frame(width: 12)
                                        Image(systemName: "calendar")
                                            .font(.caption).foregroundStyle(.purple)
                                        Text(group.meeting.title)
                                            .font(.subheadline).fontWeight(.semibold)
                                        Spacer()
                                        Text(String(format: loc("speech_count_fmt_short"), group.clips.count))
                                            .font(.caption2).foregroundStyle(.tertiary)
                                        Text(formatDate(group.meeting.createdAt))
                                            .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(.purple.opacity(0.06))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteMeetingClipsTarget = group
                                        showDeleteMeetingClipsConfirm = true
                                    } label: {
                                        Label(loc("delete_meeting_clips"), systemImage: "trash")
                                    }
                                }

                                // 该会议的发言片段（折叠时隐藏）
                                if !collapsedGroups.contains(group.id) {
                                    ForEach(group.clips, id: \.id) { clip in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(clip.cleanedText ?? clip.originalText)
                                            .font(.body)
                                        HStack {
                                            Button {
                                                playClip(clip, meeting: group.meeting)
                                            } label: {
                                                Image(systemName: clipPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                    .font(.caption).foregroundStyle(.blue)
                                            }
                                            .buttonStyle(.plain)
                                            Text(formatTime(clip.startTime))
                                                .font(.caption2).foregroundStyle(.secondary)
                                            Text("· \(String(format: "%.1f", clip.endTime - clip.startTime))s")
                                                .font(.caption2).foregroundStyle(.secondary)
                                            Spacer()
                                            // 删除该条发言
                                            Button {
                                                deleteClipTarget = clip
                                                showDeleteClipConfirm = true
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.caption).foregroundStyle(.red.opacity(0.5))
                                            }
                                            .buttonStyle(.plain)
                                            .help(loc("delete_speech_clip"))
                                            // 重新分配说话人
                                            Menu {
                                                ForEach(contacts) { contact in
                                                    Button {
                                                        reassignClip(clip, to: contact)
                                                    } label: {
                                                        Text(clip.contactId == contact.id ? "✓  \(contact.name)" : "     \(contact.name)")
                                                    }
                                                }
                                                Divider()
                                                Button {
                                                    reassignClipToNewSpeaker(clip)
                                                } label: {
                                                    Text("+ \(loc("add_person"))")
                                                }
                                            } label: {
                                                Image(systemName: "person.fill.questionmark")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            .menuStyle(.borderlessButton)
                                            .frame(width: 20)
                                        }
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 6)
                                    Divider().padding(.leading, 20)
                                }
                                }  // closes if !collapsedGroups
                            }
                            .background(.regularMaterial.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    private var companyStats: [String: Int] {
        var stats: [String: Int] = [:]
        var noCompany = 0
        for c in contacts {
            if let company = c.company, !company.isEmpty {
                stats[company, default: 0] += 1
            } else {
                noCompany += 1
            }
        }
        if noCompany > 0 { stats[loc("no_company")] = noCompany }
        return stats
    }

    private func personColor(_ name: String) -> Color {
        let c: [Color] = [.purple, .blue, .orange, .green, .pink, .teal, .indigo, .mint]
        return c[abs(name.hashValue) % c.count]
    }

    private func setDirtyIfChanged(_ contact: Contact) {
        guard selectedContact?.id == contact.id else { return }
        let nameChanged = editingAttrName.trimmingCharacters(in: .whitespaces) != contact.name
        let roleChanged = editingAttrRole.trimmingCharacters(in: .whitespaces) != (contact.role ?? "")
        let companyChanged = editingAttrCompany.trimmingCharacters(in: .whitespaces) != (contact.company ?? "")
        isDirty = nameChanged || roleChanged || companyChanged
    }

    private func playClip(_ clip: SpeechClip, meeting: Meeting) {
        let url = meeting.localAudioURL
        clipPlayer.playbackEndTime = clip.endTime
        clipPlayer.seek(to: clip.startTime)
        if !clipPlayer.hasPlayer {
            clipPlayer.startPlaying(url: url)
            // 等播放器初始化后再 seek 一次
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                clipPlayer.playbackEndTime = clip.endTime
                clipPlayer.seek(to: clip.startTime)
                if !clipPlayer.isPlaying { clipPlayer.resume() }
            }
        } else if !clipPlayer.isPlaying {
            clipPlayer.resume()
        }
    }

    private func reassignClip(_ clip: SpeechClip, to contact: Contact) {
        do {
            try db.updateSpeechClipContact(clipId: clip.id, speakerLabel: contact.name, contactId: contact.id)
            refreshClips()
        } catch {
            AppLog.warn("reassignClip failed clip=\(clip.id): \(error.localizedDescription)")
        }
    }

    private func reassignClipToNewSpeaker(_ clip: SpeechClip) {
        // 弹出新增联系人弹窗，保存后自动分配
        showAddSheet = true
        // 记录待分配的 clip，在 onAppear 刷新联系人列表后处理
        pendingReassignClip = clip
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t)/60, s = Int(t)%60
        return String(format: "%02d:%02d", m, s)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func refreshClips() {
        guard let selected = selectedContact else { return }
        let items = db.fetchSpeechClipsGroupedByMeeting(forContact: selected.id)
        groupedClips = items.map { PersonGroupedClips(meeting: $0.meeting, clips: $0.clips) }
    }
}

struct ContactEditView: View {
    var existing: Contact?
    var onSave: (Contact) -> Void
    var onCancel: () -> Void
    @State private var name = ""
    @State private var role = ""
    @State private var company = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(existing != nil ? loc("edit") : loc("add_person")).font(.headline)
            TextField(loc("name"), text: $name).textFieldStyle(.roundedBorder)
            TextField(loc("role_hint"), text: $role).textFieldStyle(.roundedBorder)
            TextField(loc("org_hint"), text: $company).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                Button(loc("cancel")) { onCancel() }.controlSize(.large); Spacer()
                Button(loc("save")) {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    onSave(Contact(id: existing?.id ?? UUID().uuidString, name: n,
                        role: role.trimmingCharacters(in: .whitespaces).isEmpty ? nil : role.trimmingCharacters(in: .whitespaces),
                        company: company.trimmingCharacters(in: .whitespaces).isEmpty ? nil : company.trimmingCharacters(in: .whitespaces),
                        avatarUrl: existing?.avatarUrl, createdAt: existing?.createdAt ?? Date(), updatedAt: Date()))
                }.buttonStyle(.borderedProminent).tint(.purple).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).controlSize(.large)
            }
        }.padding().frame(width: 320)
        .onAppear { if let c = existing { name = c.name; role = c.role ?? ""; company = c.company ?? "" } }
    }
}
