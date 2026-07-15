import SwiftUI
import AppKit

struct DebugLogView: View {
    @State private var log: String = ""
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc("debug_log")).font(.headline)
                Spacer()
                Button(loc("refresh")) { loadLog() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button { copyLog() } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help(loc("copy"))
                .disabled(log.isEmpty)
                Button { clearLog() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help(loc("delete"))
                .disabled(log.isEmpty)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(log.isEmpty ? loc("debug_log_empty") : log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("bottom")
                }
                .onAppear {
                    loadLog()
                    timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                        loadLog()
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onDisappear { timer?.invalidate() }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func loadLog() {
        let logURL = Self.logFileURL
        if let data = try? Data(contentsOf: logURL),
           let text = String(data: data, encoding: .utf8) {
            log = text
        } else {
            log = ""
        }
    }

    private func copyLog() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log, forType: .string)
    }

    private func clearLog() {
        try? Data().write(to: Self.logFileURL)
        log = ""
    }

    private static var logFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("debug.log")
    }
}
