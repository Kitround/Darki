import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Card button style (bouton principal)

/// Bouton plein largeur à fond arrondi, avec états survol/pression — proche
/// du bouton « Pause syncing » de la référence. S'adapte au clair/sombre.
private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CardButtonBody(configuration: configuration)
    }

    private struct CardButtonBody: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(
                            configuration.isPressed ? 0.16 : (hovering ? 0.11 : 0.07)
                        ))
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
        }
    }
}

// MARK: - Popover background

/// Matériau de fenêtre natif (type popover) en fond du menu. Indispensable :
/// sans lui, la fenêtre est transparente et le texte du mode clair devient
/// illisible sur un bureau sombre. S'adapte automatiquement clair/sombre.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
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
    @State private var hasAppeared = false

    @Environment(\.colorScheme) private var colorScheme

    private let controller = AppearanceController.shared

    // ── Couleurs d'accent (contrastées dans les deux apparences) ─────────────
    /// Soleil : l'orange passe bien sur clair comme sur sombre.
    private var lightAccent: Color { .orange }
    /// Lune : violet vif sur fond sombre, indigo plus profond sur fond clair
    /// (sinon le violet clair est peu lisible en mode clair).
    private var darkAccent: Color { colorScheme == .light ? .indigo : .purple }

    // ── Helpers horaires ─────────────────────────────────────────────────────
    private let step = 10
    private var timeSlots: [Int] { stride(from: 0, to: 24 * 60, by: step).map { $0 } }
    private func formatSlot(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    private func snap(_ hour: Int, _ minute: Int) -> Int { ((hour * 60 + minute) / step) * step }

    private var startSlot: Binding<Int> {
        Binding(get: { snap(startHour, startMinute) },
                set: { v in startHour = v / 60; startMinute = v % 60; controller.scheduleChanged() })
    }
    private var endSlot: Binding<Int> {
        Binding(get: { snap(endHour, endMinute) },
                set: { v in endHour = v / 60; endMinute = v % 60; controller.scheduleChanged() })
    }

    // ── Texte dérivé ─────────────────────────────────────────────────────────
    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).map { "v\($0)" } ?? ""
    }

    /// Sous-titre du header : plage horaire en mode auto, sinon mode courant.
    private var subtitle: String {
        if autoMode {
            return "\(formatSlot(snap(startHour, startMinute))) – \(formatSlot(snap(endHour, endMinute)))"
        }
        return String(localized: isDark ? "subtitle_dark" : "subtitle_light")
    }

    /// Prochaine bascule automatique ("Passe en clair à 07:00").
    private var nextSwitchText: String {
        let cal = Calendar.current
        let now = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        let dark = start < end ? (now >= start && now < end) : (now >= start || now < end)
        return dark
            ? String(format: String(localized: "auto_to_light"), formatSlot(snap(endHour, endMinute)))
            : String(format: String(localized: "auto_to_dark"), formatSlot(snap(startHour, startMinute)))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                primaryButton

                VStack(alignment: .leading, spacing: 12) {
                    toggleRow(icon: "clock.arrow.2.circlepath",
                              title: "auto_mode", help: "auto_mode_help",
                              isOn: $autoMode) { controller.autoModeChanged($0) }

                    if autoMode { scheduleBlock }
                }

                toggleRow(icon: "power",
                          title: "launch_at_login", help: "launch_at_login_help",
                          isOn: $launchAtLogin) { setLaunchAtLogin($0) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(VisualEffectBackground().ignoresSafeArea())
        .animation(hasAppeared ? .smooth(duration: 0.30) : nil, value: isDark)
        .animation(hasAppeared ? .snappy(duration: 0.22) : nil, value: autoMode)
        .onAppear {
            syncState()
            hasAppeared = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 22))
                .foregroundStyle(isDark ? darkAccent : lightAccent)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Darki").font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button {
            toggleDarkMode()
            animateToggleIcon.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                    .symbolEffect(.bounce, options: .speed(1.4), value: animateToggleIcon)
                    .foregroundStyle(isDark ? lightAccent : darkAccent)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(isDark ? "switch_to_light" : "switch_to_dark")
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(CardButtonStyle())
    }

    // MARK: - Schedule

    private var scheduleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dark_mode_schedule")
                .textCase(.uppercase)
                .font(.caption2)
                .fontWeight(.semibold)
                .kerning(0.6)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            timeRow(icon: "moon.fill", label: "start", slot: startSlot)
            timeRow(icon: "sun.max.fill", label: "end", slot: endSlot)

            Label(nextSwitchText, systemImage: "clock")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .padding(.top, 1)
        }
        .padding(.leading, 30)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func timeRow(icon: String, label: LocalizedStringKey, slot: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(label)
            Spacer()
            Picker("", selection: slot) {
                ForEach(timeSlots, id: \.self) { minutes in
                    Text(formatSlot(minutes)).monospacedDigit().tag(minutes)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    // MARK: - Toggle row

    private func toggleRow(icon: String,
                           title: LocalizedStringKey,
                           help: LocalizedStringKey,
                           isOn: Binding<Bool>,
                           onChange: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.blue)
                .accessibilityLabel(Text(title))
                .onChange(of: isOn.wrappedValue) { _, v in onChange(v) }
        }
        .help(help)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(appVersion)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
    }

    // MARK: - Actions

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
