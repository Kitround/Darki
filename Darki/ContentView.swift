import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Liquid Glass helper (macOS 26+ only)
// Sur macOS 14/15, le ViewModifier est un no-op transparent.
private struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular.interactive())
        } else {
            content
        }
    }
}

private extension View {
    func adaptiveGlass() -> some View { modifier(GlassButtonModifier()) }
}

// MARK: - Main View

struct ContentView: View {
    @AppStorage("isDark") private var isDark = false
    @AppStorage("autoMode") private var autoMode = false
    @AppStorage("startHour") private var startHour = 20
    @AppStorage("startMinute") private var startMinute = 0
    @AppStorage("endHour") private var endHour = 7
    @AppStorage("endMinute") private var endMinute = 0
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    @State private var animateToggleIcon = false

    private let controller = AppearanceController.shared

    // ── Time picker helpers ──────────────────────────────────────────────────
    private let step = 10
    private var timeSlots: [Int] { stride(from: 0, to: 24 * 60, by: step).map { $0 } }

    private func formatSlot(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func snap(_ hour: Int, _ minute: Int) -> Int {
        ((hour * 60 + minute) / step) * step
    }

    private var startSlot: Binding<Int> {
        Binding(
            get: { snap(startHour, startMinute) },
            set: { v in startHour = v / 60; startMinute = v % 60; controller.scheduleChanged() }
        )
    }

    private var endSlot: Binding<Int> {
        Binding(
            get: { snap(endHour, endMinute) },
            set: { v in endHour = v / 60; endMinute = v % 60; controller.scheduleChanged() }
        )
    }

    /// Décrit la prochaine bascule automatique ("Passe en clair à 07:00").
    private var nextSwitchText: String {
        let calendar = Calendar.current
        let now = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        let inDarkWindow = start < end ? (now >= start && now < end) : (now >= start || now < end)
        return inDarkWindow
            ? String(format: String(localized: "auto_to_light"), formatSlot(end))
            : String(format: String(localized: "auto_to_dark"), formatSlot(start))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isDark ? .purple : .orange, .yellow.opacity(0.6))
                    .font(.title2)
                    // Morph fluide entre soleil et lune au changement d'état.
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                    // Frame fixe = l'icône la plus large (sun.max.fill) fixe la
                    // taille ; moon.fill se centre dedans sans décaler le layout.
                    .frame(width: 28, height: 28)

                Text("Darki").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            // ── Toggle principal ─────────────────────────────────────────────
            Button {
                toggleDarkMode()
                animateToggleIcon.toggle()
            } label: {
                HStack {
                    Image(systemName: isDark ? "sun.max" : "moon")
                        .symbolEffect(.bounce, options: .speed(1.4), value: animateToggleIcon)
                        .accessibilityHidden(true)
                    Text(isDark ? "switch_to_light" : "switch_to_dark")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isDark ? .orange : .purple)
            // Liquid Glass uniquement sur macOS 26+, sinon borderedProminent suffit.
            .adaptiveGlass()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Mode automatique ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Toggle("auto_mode", isOn: $autoMode)
                    .help("auto_mode_help")
                    .onChange(of: autoMode) { _, newValue in
                        controller.autoModeChanged(newValue)
                    }

                scheduleSection
                    // .disabled() seul : SwiftUI gère le feedback visuel natif.
                    .disabled(!autoMode)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Lancement au démarrage ───────────────────────────────────────
            Toggle("launch_at_login", isOn: $launchAtLogin)
                .help("launch_at_login_help")
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // ── Quitter ──────────────────────────────────────────────────────
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "xmark.circle").accessibilityHidden(true)
                    Text("quit")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("q")
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
        }
        .frame(width: 300)
        // Hauteur fixe : empêche tout redimensionnement au changement d'icône.
        .fixedSize(horizontal: false, vertical: true)
        // Anime header + teinte + libellés quand l'état bascule.
        .animation(.smooth(duration: 0.35), value: isDark)
        .onAppear(perform: syncState)
    }

    // MARK: - Schedule section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dark_mode_schedule")
                .font(.caption)
                .foregroundStyle(.secondary)

            timeRow(label: "start", slot: startSlot)
            timeRow(label: "end",   slot: endSlot)

            // Aperçu vivant de la prochaine bascule.
            Label(nextSwitchText, systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.leading, 8)
    }

    @ViewBuilder
    private func timeRow(label: LocalizedStringKey, slot: Binding<Int>) -> some View {
        HStack {
            Text(label).frame(width: 50, alignment: .leading)

            // Un seul Picker "HH:mm", palier 10 min, style .menu natif.
            Picker("", selection: slot) {
                ForEach(timeSlots, id: \.self) { minutes in
                    Text(formatSlot(minutes)).tag(minutes)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            // Largeur fixe pour que "23:50" ne soit pas tronqué.
            .frame(width: 80)
        }
    }

    // MARK: - Actions

    /// Aligne l'UI sur l'état réel du système à l'ouverture du menu.
    private func syncState() {
        isDark = AppleScriptManager.isSystemDark
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    private func toggleDarkMode() {
        let newMode = !isDark
        Task {
            if await controller.setDark(newMode) {
                isDark = newMode
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            #if DEBUG
            print("Launch at login \(enabled ? "register" : "unregister") failed: \(error)")
            #endif
        }
    }
}
