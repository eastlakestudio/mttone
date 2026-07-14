import SwiftUI

@main
struct MttoneApp: App {
    @State private var databaseManager = DatabaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 760)
                .environment(databaseManager)
                .task {
                    try? await WhisperService.shared.initialize()
                }
        }
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
    }
}
