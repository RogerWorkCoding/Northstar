import SwiftUI
import AppKit

// 🧭 Northstar Navigator (Mac), step 1: a star in the menu bar that finds files when you ask on your iPhone.
// It only LOOKS: it never moves, changes, sends or deletes anything.

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct NavigatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = NavigatorModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Image(systemName: model.isWorking ? "sparkle.magnifyingglass" : "sparkle")
                .accessibilityLabel("Northstar Navigator")
        }
        .menuBarExtraStyle(.window)
    }
}
