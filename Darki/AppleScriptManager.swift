import Foundation

/// Lecture / écriture de l'apparence système (clair ↔ sombre).
///
/// La **lecture** est native et gratuite (aucun processus lancé) ; seule
/// l'**écriture** passe par `osascript`, faute d'API publique pour modifier
/// l'apparence du système.
enum AppleScriptManager {

    /// Apparence courante, lue directement dans les préférences globales.
    /// À l'inverse d'un appel AppleScript, c'est instantané et sans coût.
    static var isSystemDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// Bascule l'apparence système. Retourne `true` si l'opération a réussi.
    @discardableResult
    static func setDarkMode(_ enabled: Bool) async -> Bool {
        let script = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to \(enabled)
                end tell
            end tell
            """
        let result = await runOsascript(script)
        #if DEBUG
        if result.success {
            print("✅ Mode système → \(enabled ? "sombre" : "clair")")
        } else {
            print("❌ Échec du changement de mode : \(result.output)")
        }
        #endif
        return result.success
    }

    /// Exécute un script via `osascript` sur une file de fond, sans bloquer
    /// l'appelant (pont `Process` → `async` via une continuation).
    private static func runOsascript(_ source: String) async -> (success: Bool, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (false, error.localizedDescription))
                    return
                }
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: (process.terminationStatus == 0, output))
            }
        }
    }
}
