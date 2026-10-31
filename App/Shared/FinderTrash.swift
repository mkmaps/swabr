import AppKit

/// Asks Finder to move a path to the Trash. Finder requests the administrator password itself
/// when the item belongs to root or another account, and keeps "Put Back" working.
enum FinderTrash {
    static let move: @Sendable (String) -> String? = { path in
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"Finder\" to delete (POSIX file \"\(escaped)\" as alias)"
        // NSAppleScript must run on the main thread; the uninstall itself runs in the background.
        return DispatchQueue.main.sync {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            guard let error else { return nil }
            let code = error[NSAppleScript.errorNumber] as? Int
            switch code {
            case -128: return String(localized: "Vom Benutzer abgebrochen")
            case -1743: return String(localized: "Swabr darf den Finder nicht steuern (Systemeinstellungen → Datenschutz & Sicherheit → Automation)")
            default: return error[NSAppleScript.errorMessage] as? String ?? String(localized: "Finder konnte das Objekt nicht löschen")
            }
        }
    }
}

/// Moves items to the Trash through `NSWorkspace.recycle`, the same service the Finder uses. It is public
/// API that works in the App Store sandbox; for items owned by root or another account macOS shows its own
/// authentication dialog instead of failing.
enum WorkspaceTrash {
    static let move: @Sendable (String) -> String? = { path in
        let done = DispatchSemaphore(value: 0)
        let box = ResultBox()
        DispatchQueue.main.async {
            NSWorkspace.shared.recycle([URL(fileURLWithPath: path)]) { _, error in
                box.error = error.map { e in
                    (e as NSError).code == NSUserCancelledError ? String(localized: "Vom Benutzer abgebrochen") : e.localizedDescription
                }
                done.signal()
            }
        }
        // The caller runs in the background; the completion arrives on another queue.
        if done.wait(timeout: .now() + 300) == .timedOut { return String(localized: "Keine Antwort vom Papierkorb") }
        return box.error
    }

    private final class ResultBox: @unchecked Sendable {
        var error: String?
    }
}
