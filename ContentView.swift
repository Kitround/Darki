import SwiftUI
import AppKit
import ServiceManagement

struct ContentView: View {
    @AppStorage("isDark") private var isDark = false
    @AppStorage("autoMode") private var autoMode = false
    @AppStorage("startHour") private var startHour = 20
    @AppStorage("startMinute") private var startMinute = 0
    @AppStorage("endHour") private var endHour = 7
    @AppStorage("endMinute") private var endMinute = 0
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    @State private var animateHeaderIcon = false
    @State private var animateToggleIcon = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header avec animation
            HStack {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isDark ? .purple : .orange, .yellow.opacity(0.6))
                    .font(.title2)
                    .symbolEffect(.bounce, value: animateHeaderIcon)
                
                Text("Darki")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            // Bouton toggle avec animation
            Button {
                toggleDarkMode()
                animateToggleIcon.toggle()
            } label: {
                HStack {
                    Image(systemName: isDark ? "sun.max" : "moon")
                        .symbolEffect(.bounce, options: .speed(1.4), value: animateToggleIcon)
                    
                    Text(isDark ? "switch_to_light" : "switch_to_dark")
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .tint(isDark ? .orange : .purple)
            
            Divider()
            
            // Auto mode
            VStack(alignment: .leading, spacing: 10) {
                Toggle("auto_mode", isOn: $autoMode)
                    .help("auto_mode_help")
                    .onChange(of: autoMode) { _, newValue in
                        // Notifier l'AppDelegate
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AutoModeChanged"),
                            object: newValue
                        )
                    }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("dark_mode_schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Heure de début
                    HStack {
                        Text("start")
                            .frame(width: 50, alignment: .leading)
                        
                        Picker("", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Text(":")
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $startMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    
                    // Heure de fin
                    HStack {
                        Text("end")
                            .frame(width: 50, alignment: .leading)
                        
                        Picker("", selection: $endHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Text(":")
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $endMinute) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    
                    Text("schedule_description")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.leading, 8)
                .disabled(!autoMode)
                .opacity(autoMode ? 1.0 : 0.5)
            }
            
            Divider()
            
            // Launch at login
            Toggle("launch_at_login", isOn: $launchAtLogin)
                .help("launch_at_login_help")
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            
            Divider()
            
            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("quit")
                }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("q")
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            checkMode()
            checkLaunchAtLogin()
        }
        .onChange(of: isDark) { _, _ in
            animateHeaderIcon.toggle()
        }
    }
    
    // MARK: - Dark mode logic
    func checkMode() {
        AppleScriptManager.getDarkMode { result in
            isDark = result ?? false
        }
    }
    
    func toggleDarkMode() {
        let newMode = !isDark
        AppleScriptManager.setDarkMode(newMode) { success in
            if success {
                isDark = newMode
            }
        }
    }
    
    // MARK: - Launch at login
    func checkLaunchAtLogin() {
        let isEnabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != isEnabled {
            launchAtLogin = isEnabled
        }
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}

