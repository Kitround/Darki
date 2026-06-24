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
            // .template assure une adaptation correcte en mode clair/sombre
            // et respecte la taille standard de la menu bar (macOS 14+)
            Image(systemName: isDark ? "moon.circle.fill" : "sun.max.circle.fill")
                .renderingMode(.template)
                .accessibilityLabel(isDark ? "Dark mode active" : "Light mode active")
        }
        .menuBarExtraStyle(.window)
    }
}
