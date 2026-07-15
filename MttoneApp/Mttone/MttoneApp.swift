import SwiftUI
#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 移除不必要的系统菜单，仅保留 App 菜单（关于、退出等）
        guard let mainMenu = NSApp.mainMenu else { return }
        let toRemove = ["File", "Edit", "View", "Format", "Window", "Help"]
        for item in mainMenu.items where toRemove.contains(item.title) {
            mainMenu.removeItem(item)
        }
    }
}
#endif

@main
struct MttoneApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于听纪") {
                    showAboutWindow()
                }
            }
        }
    }

    #if os(macOS)
    private func showAboutWindow() {
        // 已存在则前置
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "about" }) {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        // 新建 About 窗口
        let aboutVC = NSHostingController(rootView: AboutView().background(.regularMaterial))
        let aboutWindow = NSWindow(contentViewController: aboutVC)
        aboutWindow.identifier = NSUserInterfaceItemIdentifier("about")
        aboutWindow.title = "关于听纪"
        aboutWindow.styleMask = [.titled, .closable]
        aboutWindow.setContentSize(NSSize(width: 460, height: 440))
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
    }
    #endif
}
