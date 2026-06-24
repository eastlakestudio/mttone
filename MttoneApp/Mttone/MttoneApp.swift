import SwiftUI

@main
struct MttoneApp: App {
    @State private var databaseManager = DatabaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(databaseManager)
                .task {
                    // 软件启动时后台预加载大模型，实现秒开录音
                    try? await WhisperService.shared.initialize()
                }
        }
    }
}
