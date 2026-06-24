import SwiftUI

@main
struct MttoneApp: App {
    @State private var databaseManager = DatabaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(databaseManager)
        }
    }
}
