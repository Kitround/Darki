import Foundation
import AppKit

struct AppleScriptManager {
    static func setDarkMode(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to \(enabled)
                end tell
            end tell
            """)
            
            let result = script?.executeAndReturnError(&error)
            
            DispatchQueue.main.async {
                if error != nil {
                    print("AppleScript Error: \(error!)")
                    completion(false)
                } else {
                    completion(result != nil)
                }
            }
        }
    }
    
    static func getDarkMode(completion: @escaping (Bool?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: """
            tell application "System Events"
                tell appearance preferences
                    return dark mode as boolean
                end tell
            end tell
            """)
            
            let result = script?.executeAndReturnError(&error)
            
            DispatchQueue.main.async {
                if let result = result, error == nil {
                    completion(result.booleanValue)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
