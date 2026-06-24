import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Empêche l'App Nap pour que les timers de bascule restent fiables —
        // SANS empêcher la veille système (option `.idleSystemSleepDisabled`
        // retirée : elle gardait le Mac éveillé en permanence pour rien, les
        // timers étant de toute façon reprogrammés au réveil).
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Bascule automatique du mode sombre"
        )

        // Le masquage du Dock est géré par LSUIElement (Info.plist).
        AppearanceController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        AppearanceController.shared.stop()
    }
}
