import AppKit

/// Source de vérité unique pour l'apparence et la planification automatique.
///
/// Regroupe ce qui était auparavant éclaté entre `AppDelegate` et des
/// `NotificationCenter` à clés textuelles :
/// - les timers de bascule quotidienne ;
/// - la réconciliation de l'état au réveil du Mac ;
/// - la synchronisation avec les changements d'apparence faits **hors** de
///   l'app (Réglages Système, Raccourcis…), pour que l'icône reste juste.
///
/// L'UI persiste ses réglages via `@AppStorage` ; ce contrôleur les relit
/// dans `UserDefaults` et écrit `isDark`, observé en KVO par l'icône.
@MainActor
final class AppearanceController {

    static let shared = AppearanceController()
    private init() {}

    private let defaults = UserDefaults.standard
    private var startTimer: Timer?
    private var endTimer: Timer?

    private enum Key {
        static let isDark = "isDark"
        static let autoMode = "autoMode"
        static let startHour = "startHour"
        static let startMinute = "startMinute"
        static let endHour = "endHour"
        static let endMinute = "endMinute"
    }

    // MARK: - Cycle de vie

    func start() {
        // Aligne l'état persistant sur l'apparence réelle au lancement.
        defaults.set(AppleScriptManager.isSystemDark, forKey: Key.isDark)

        // Apparence changée hors de l'app → on rafraîchit l'icône.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Au réveil, les timers sont périmés : on les reprogramme.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        if defaults.bool(forKey: Key.autoMode) {
            scheduleTimers()
        }
    }

    func stop() {
        cancelTimers()
    }

    // MARK: - Actions publiques (appelées depuis l'UI)

    /// Bascule manuelle. Met à jour l'état persistant si l'opération réussit.
    @discardableResult
    func setDark(_ enabled: Bool) async -> Bool {
        let success = await AppleScriptManager.setDarkMode(enabled)
        if success {
            defaults.set(enabled, forKey: Key.isDark)
        }
        return success
    }

    /// L'utilisateur a (dés)activé le mode automatique.
    func autoModeChanged(_ enabled: Bool) {
        if enabled {
            scheduleTimers()
        } else {
            cancelTimers()
        }
    }

    /// L'utilisateur a modifié la plage horaire.
    func scheduleChanged() {
        guard defaults.bool(forKey: Key.autoMode) else { return }
        scheduleTimers()
    }

    // MARK: - Observateurs système

    @objc private func systemAppearanceChanged() {
        defaults.set(AppleScriptManager.isSystemDark, forKey: Key.isDark)
    }

    @objc private func systemDidWake() {
        guard defaults.bool(forKey: Key.autoMode) else { return }
        scheduleTimers()
    }

    // MARK: - Timers

    private func scheduleTimers() {
        cancelTimers()

        if let startDate = nextDate(hour: defaults.integer(forKey: Key.startHour),
                                    minute: defaults.integer(forKey: Key.startMinute)) {
            startTimer = makeDailyTimer(firingAt: startDate) { [weak self] in
                _ = await self?.setDark(true)
            }
        }

        if let endDate = nextDate(hour: defaults.integer(forKey: Key.endHour),
                                  minute: defaults.integer(forKey: Key.endMinute)) {
            endTimer = makeDailyTimer(firingAt: endDate) { [weak self] in
                _ = await self?.setDark(false)
            }
        }

        // On peut déjà être dans la plage : on corrige immédiatement.
        reconcileCurrentState()
    }

    private func cancelTimers() {
        startTimer?.invalidate()
        startTimer = nil
        endTimer?.invalidate()
        endTimer = nil
    }

    private func makeDailyTimer(firingAt date: Date, action: @escaping @Sendable () async -> Void) -> Timer {
        let timer = Timer(fire: date, interval: 86_400, repeats: true) { _ in
            Task { @MainActor in await action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    /// Aligne l'apparence courante sur ce que la plage horaire impose.
    /// Lecture native (aucun processus) ; n'écrit que si nécessaire.
    private func reconcileCurrentState() {
        let shouldBeDark = scheduleWantsDark(at: Date())
        guard AppleScriptManager.isSystemDark != shouldBeDark else { return }
        Task { await setDark(shouldBeDark) }
    }

    /// Le mode sombre doit-il être actif à l'instant donné ?
    /// Gère le cas d'une plage qui chevauche minuit (ex. 20h → 7h).
    private func scheduleWantsDark(at date: Date) -> Bool {
        let calendar = Calendar.current
        let now = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = defaults.integer(forKey: Key.startHour) * 60 + defaults.integer(forKey: Key.startMinute)
        let end = defaults.integer(forKey: Key.endHour) * 60 + defaults.integer(forKey: Key.endMinute)

        return start < end ? (now >= start && now < end) : (now >= start || now < end)
    }

    /// Prochaine occurrence d'une heure donnée (aujourd'hui ou demain).
    private func nextDate(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let date = calendar.date(from: components) else { return nil }
        return date <= now ? calendar.date(byAdding: .day, value: 1, to: date) : date
    }
}
