import Foundation
import SwabrCore

/// Runs fixed root operations: through the approved helper without a prompt, otherwise after one standard
/// macOS password prompt, by running the same helper program once. Either way the helper checks every
/// operation itself and never runs a script.
enum Privileged {
    /// One result per operation, or nil when the user cancelled the prompt or nothing could run.
    static let run: RootRunner = { operations in
        if let results = PrivilegedHelper.perform(operations) { return results }
        guard let request = try? JSONEncoder().encode(RootRequest(operations)) else { return nil }
        let helper = Bundle.main.bundleURL.appending(path: "Contents/MacOS/SwabrHelper").path
        guard FileManager.default.isExecutableFile(atPath: helper) else { return nil }
        // Only fixed characters reach the shell: the quoted helper path, base64 text and a number.
        let command = "'" + helper.replacingOccurrences(of: "'", with: "'\\''") + "' --perform "
            + request.base64EncodedString() + " --uid \(getuid())"
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        // The prompt text is shown in the password dialog, so it is localized; the command around it is not.
        let prompt = String(localized: "Swabr möchte Wartungsaufgaben ausführen.").replacingOccurrences(of: "\"", with: "'")
        let source = "do shell script \"\(escaped)\" with prompt \"\(prompt)\" with administrator privileges"
        let output: String? = DispatchQueue.main.sync {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            return error == nil ? result?.stringValue : nil
        }
        guard let output, let data = Data(base64Encoded: output.trimmingCharacters(in: .whitespacesAndNewlines)),
              let results = try? JSONDecoder().decode([RootResult].self, from: data), results.count == operations.count
        else { return nil }
        return results
    }
}

/// Login items ("Open at Login") through System Events: the same list as System Settings → General → Login Items.
enum LoginItems {
    struct Item: Identifiable, Hashable {
        var id: String { path }
        let name: String
        let path: String
        let hidden: Bool
    }

    enum Failure: Error, LocalizedError {
        case noAccess, failed(String)
        var errorDescription: String? {
            switch self {
            case .noAccess: String(localized: "Swabr darf System Events nicht steuern. Bitte unter Systemeinstellungen → Datenschutz & Sicherheit → Automation erlauben.")
            case .failed(let m): m
            }
        }
    }

    static func list() throws -> [Item] {
        let script = """
        set out to ""
        tell application "System Events"
            repeat with li in login items
                set out to out & (name of li) & tab & (path of li) & tab & (hidden of li) & linefeed
            end repeat
        end tell
        return out
        """
        let text = try run(script)
        return text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count == 3 else { return nil }
            return Item(name: f[0], path: f[1], hidden: f[2] == "true")
        }
    }

    static func add(path: String, hidden: Bool) throws {
        _ = try run("tell application \"System Events\" to make login item at end with properties {path:\"\(quote(path))\", hidden:\(hidden)}")
    }

    static func remove(_ item: Item) throws {
        _ = try run("tell application \"System Events\" to delete (every login item whose path is \"\(quote(item.path))\")")
    }

    static func setHidden(_ item: Item, _ hidden: Bool) throws {
        _ = try run("tell application \"System Events\" to set hidden of (every login item whose path is \"\(quote(item.path))\") to \(hidden)")
    }

    private static func quote(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// NSAppleScript has to run on the main thread.
    private static func run(_ source: String) throws -> String {
        let work = { () -> Result<String, Failure> in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                if (error[NSAppleScript.errorNumber] as? Int) == -1743 { return .failure(.noAccess) }
                return .failure(.failed(error[NSAppleScript.errorMessage] as? String ?? String(localized: "System Events hat nicht geantwortet")))
            }
            return .success(result?.stringValue ?? "")
        }
        return try (Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)).get()
    }

    /// Paths of login items whose program no longer exists, or nil when System Events could not be asked.
    static func missing() -> [String]? {
        (try? list())?.map(\.path).filter { !$0.isEmpty && !FileManager.default.fileExists(atPath: $0) }
    }
}
