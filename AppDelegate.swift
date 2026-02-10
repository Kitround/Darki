import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Empêcher App Nap
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Changement automatique du mode sombre"
        )
        
        // Démarrer le timer si le mode auto est activé
        if UserDefaults.standard.bool(forKey: "autoMode") {
            startTimer()
        }
        
        // Observer les changements du mode auto
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoModeChanged),
            name: NSNotification.Name("AutoModeChanged"),
            object: nil
        )
    }
    
    @objc func autoModeChanged(_ notification: Notification) {
        if let enabled = notification.object as? Bool {
            if enabled {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    func startTimer() {
        stopTimer()
        
        checkSchedule()
        
        let newTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkSchedule()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        
        print("✓ Timer démarré")
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("✗ Timer arrêté")
    }
    
    func checkSchedule() {
        let defaults = UserDefaults.standard
        let startHour = defaults.integer(forKey: "startHour")
        let startMinute = defaults.integer(forKey: "startMinute")
        let endHour = defaults.integer(forKey: "endHour")
        let endMinute = defaults.integer(forKey: "endMinute")
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        let startTimeInMinutes = startHour * 60 + startMinute
        let endTimeInMinutes = endHour * 60 + endMinute
        
        let shouldBeDark: Bool
        
        if startTimeInMinutes < endTimeInMinutes {
            shouldBeDark = currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes < endTimeInMinutes
        } else {
            shouldBeDark = currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes < endTimeInMinutes
        }
        
        print("⏰ Vérification: \(String(format: "%02d:%02d", currentHour, currentMinute)) - Devrait être sombre: \(shouldBeDark)")
        
        AppleScriptManager.getDarkMode { currentIsDark in
            guard let currentIsDark = currentIsDark, currentIsDark != shouldBeDark else {
                return
            }
            
            print("🔄 Changement du mode vers: \(shouldBeDark ? "sombre" : "clair")")
            AppleScriptManager.setDarkMode(shouldBeDark) { success in
                if success {
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(shouldBeDark, forKey: "isDark")
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        stopTimer()
    }
}

