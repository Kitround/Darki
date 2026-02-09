import SwiftUI
import AppKit
import ServiceManagement

@main
struct DarkiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("isDark") private var isDark = false
    @AppStorage("autoMode") private var autoMode = false
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: isDark ? "moon.circle.fill" : "sun.max.circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
