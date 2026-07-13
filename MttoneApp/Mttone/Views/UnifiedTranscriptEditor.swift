import SwiftUI

struct UnifiedTranscriptEditor: View {
    @Binding var segments: [TranscriptSegment]
    var attendees: [String] = []
    var contacts: [String] = []
    var onPlaySegment: ((TranscriptSegment) -> Void)?
    @Environment(DatabaseManager.self) private var db

    private var allSpeakers: [String] {
        var seen = Set<String>()
        return segments.map { $0.speakerLabel }.filter { seen.insert($0).inserted }
    }

    private let speakerColors: [Color] = [.purple, .blue, .orange, .green, .pink, .teal, .indigo, .mint, .cyan, .brown, .yellow]

    private func colorForSpeaker(_ name: String) -> Color {
        guard let idx = allSpeakers.firstIndex(of: name) else { return .gray }
        return speakerColors[idx % speakerColors.count]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(segments.filter { $0.isFinal }.enumerated()), id: \.element.id) { idx, seg in
                    TranscriptRow(
                        segment: seg,
                        index: idx,
                        total: segments.count,
                        existingSpeakers: allSpeakers.filter { $0 != seg.speakerLabel },
                        speakerColor: colorForSpeaker(seg.speakerLabel),
                        onTextChange: { newText in
                            if idx < segments.count { segments[idx].text = newText }
                        },
                        onSpeakerChange: { newSpeaker in
                            if idx < segments.count { segments[idx].speakerLabel = newSpeaker }
                        },
                        onMergeUp: {
                            mergeUp(idx)
                        },
                        onSplitAfter: { textAfter in
                            splitAfter(idx, text: textAfter)
                        },
                        onPlay: {
                            onPlaySegment?(seg)
                        }
                    )
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func splitAfter(_ idx: Int, text: String) {
        guard idx < segments.count else { return }
        let seg = segments[idx]
        let newSeg = TranscriptSegment(
            id: UUID().uuidString,
            startTime: seg.endTime,
            endTime: seg.endTime + 5,
            text: text,
            speakerLabel: seg.speakerLabel,
            contactId: seg.contactId,
            isFinal: true
        )
        segments.insert(newSeg, at: idx + 1)
    }

    private func mergeUp(_ idx: Int) {
        guard idx > 0 else { return }
        let prev = segments[idx - 1]
        let curr = segments[idx]
        guard prev.speakerLabel == curr.speakerLabel else { return }
        let mergedText: String
        if prev.text.isEmpty {
            mergedText = curr.text
        } else {
            mergedText = prev.text + " " + curr.text
        }
        segments[idx - 1] = TranscriptSegment(
            id: prev.id,
            startTime: prev.startTime,
            endTime: curr.endTime,
            text: mergedText,
            speakerLabel: prev.speakerLabel,
            contactId: prev.contactId,
            isFinal: true
        )
        segments.remove(at: idx)
    }
}

// MARK: - 行

private struct TranscriptRow: View {
    let segment: TranscriptSegment
    let index: Int
    let total: Int
    let existingSpeakers: [String]
    let speakerColor: Color
    var onTextChange: (String) -> Void
    var onSpeakerChange: (String) -> Void
    var onMergeUp: () -> Void
    var onSplitAfter: (String) -> Void
    var onPlay: (() -> Void)?

    @State private var editText: String
    @State private var showSpeakerMenu = false
    @State private var showRenamePopover = false
    @State private var newSpeakerName = ""
    @State private var skipNextNewlineCheck = false

    init(segment: TranscriptSegment, index: Int, total: Int, existingSpeakers: [String], speakerColor: Color, onTextChange: @escaping (String) -> Void, onSpeakerChange: @escaping (String) -> Void, onMergeUp: @escaping () -> Void, onSplitAfter: @escaping (String) -> Void, onPlay: (() -> Void)? = nil) {
        self.segment = segment
        self.index = index
        self.total = total
        self.existingSpeakers = existingSpeakers
        self.speakerColor = speakerColor
        self.onTextChange = onTextChange
        self.onSpeakerChange = onSpeakerChange
        self.onMergeUp = onMergeUp
        self.onSplitAfter = onSplitAfter
        self.onPlay = onPlay
        self._editText = State(initialValue: segment.text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: { onPlay?() }) {
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .frame(width: 16)
            .padding(.top, 6)
            .help("播放此段")

            Text(formatTime(segment.startTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 42, alignment: .leading)
                .padding(.top, 6)

            Menu {
                ForEach(existingSpeakers, id: \.self) { s in
                    Button(s) { onSpeakerChange(s) }
                }
                if !existingSpeakers.isEmpty { Divider() }
                Button("新建...") {
                    newSpeakerName = ""
                    showRenamePopover = true
                }
            } label: {
                Text(segment.speakerLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(speakerColor, in: Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .frame(width: 64, alignment: .leading)
            .padding(.top, 5)
            .popover(isPresented: $showRenamePopover) {
                VStack(spacing: 8) {
                    Text("新建说话人").font(.caption).foregroundStyle(.secondary)
                    TextField("姓名", text: $newSpeakerName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { confirmRename() }
                    HStack {
                        Spacer()
                        Button("取消") { showRenamePopover = false }
                        Button("确定") { confirmRename() }.buttonStyle(.borderedProminent)
                    }
                }
                .padding().frame(width: 200)
            }

            TextEditor(text: $editText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 22, maxHeight: 100)
                .onChange(of: editText) { _, newValue in
                    if skipNextNewlineCheck {
                        skipNextNewlineCheck = false
                        return
                    }
                    if newValue.contains("\n") {
                        let parts = newValue.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                        let before = parts.count > 0 ? parts[0] : ""
                        let after = parts.count > 1 ? parts[1] : ""
                        editText = before
                        onSplitAfter(after)
                    } else {
                        onTextChange(newValue)
                    }
                }

            if index > 0 {
                Button(action: onMergeUp) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(width: 16)
                .padding(.top, 7)
                .help("合并到上一行")
            } else {
                Spacer().frame(width: 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
        .onChange(of: segment.text) { _, newText in
            skipNextNewlineCheck = newText != editText
            editText = newText
        }
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func confirmRename() {
        let name = newSpeakerName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { onSpeakerChange(name); showRenamePopover = false }
    }
}
