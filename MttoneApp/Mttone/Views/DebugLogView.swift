import SwiftUI

struct DebugLogView: View {
    @State private var log: String = ""
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("调试日志").font(.headline)
                Spacer()
                Button("刷新") { loadLog() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(log.isEmpty ? "暂无日志" : log)
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
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/auranote_diag.log")),
           let text = String(data: data, encoding: .utf8) {
            log = text
        }
    }
}
