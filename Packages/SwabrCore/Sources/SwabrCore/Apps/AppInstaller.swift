import CryptoKit
import Foundation
import Security

/// Installs a vendor download over an installed app. The new copy must carry the same bundle id
/// and the same developer signature as the installed one and pass Gatekeeper, otherwise nothing changes.
public enum AppInstaller {
    public enum Result: Sendable, Equatable {
        case installed(String)
        /// A .pkg was opened in Installer; the user finishes there.
        case openedInstaller
    }

    public struct Failure: Error, LocalizedError, Sendable {
        public let message: String
        public var errorDescription: String? { message }
        init(_ message: String) { self.message = message }
    }

    public static func install(
        _ update: AppUpdate, privilegedTrash: Uninstaller.PrivilegedTrash? = nil,
        progress: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> Result {
        guard let url = update.download, url.scheme == "https" else { throw Failure(String(localized: "Keine Download-Adresse bekannt", bundle: .module)) }
        let work = FileManager.default.temporaryDirectory.appending(path: "swabr-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        progress(String(localized: "Lade \(update.app.name) \(update.available) …", bundle: .module))
        let (temp, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else {
            throw Failure(String(localized: "Download fehlgeschlagen", bundle: .module))
        }
        let file = work.appending(path: response.suggestedFilename ?? url.lastPathComponent)
        try FileManager.default.moveItem(at: temp, to: file)

        if let expected = update.sha256?.lowercased(), expected.count == 64 {
            progress(String(localized: "Prüfe Prüfsumme …", bundle: .module))
            guard try sha256(of: file) == expected else { throw Failure(String(localized: "Prüfsumme stimmt nicht, Download verworfen", bundle: .module)) }
        }

        progress(String(localized: "Entpacke …", bundle: .module))
        let kind = try detect(file)
        if kind == .pkg {
            try verifyPackage(file)
            // Installer needs the file after this function cleans up, so keep a copy outside the work folder.
            let keep = FileManager.default.temporaryDirectory.appending(path: file.lastPathComponent)
            try? FileManager.default.removeItem(at: keep)
            try FileManager.default.copyItem(at: file, to: keep)
            _ = Shell.run("/usr/bin/open", ["-a", "Installer", keep.path], timeout: 10)
            return .openedInstaller
        }
        let extracted = work.appending(path: "extracted")
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        var mount: String?
        defer { if let mount { Shell.run("/usr/bin/hdiutil", ["detach", mount, "-force"], timeout: 60) } }
        let searchRoot: URL
        switch kind {
        case .dmg:
            let mnt = work.appending(path: "mnt").path
            let r = Shell.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mnt, file.path], timeout: 120)
            guard r.status == 0 else { throw Failure(String(localized: "Festplattenimage ließ sich nicht öffnen", bundle: .module)) }
            mount = mnt
            searchRoot = URL(fileURLWithPath: mnt)
        case .zip:
            guard Shell.run("/usr/bin/ditto", ["-x", "-k", file.path, extracted.path], timeout: 300).status == 0 else { throw Failure(String(localized: "Archiv ließ sich nicht entpacken", bundle: .module)) }
            searchRoot = extracted
        case .tar:
            guard Shell.run("/usr/bin/tar", ["-xf", file.path, "-C", extracted.path], timeout: 300).status == 0 else { throw Failure(String(localized: "Archiv ließ sich nicht entpacken", bundle: .module)) }
            searchRoot = extracted
        case .pkg:
            fatalError("handled above")
        }

        guard let newApp = findApp(in: searchRoot, bundleID: update.app.bundleID) else {
            throw Failure(String(localized: "Im Download ist keine App mit der Kennung \(update.app.bundleID)", bundle: .module))
        }
        progress(String(localized: "Prüfe Signatur …", bundle: .module))
        try verifySameDeveloper(new: newApp.path, installed: update.app.path)

        // Copy out of the disk image before touching the installed app.
        let staged = work.appending(path: "staged/\(newApp.lastPathComponent)")
        try FileManager.default.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard Shell.run("/usr/bin/ditto", [newApp.path, staged.path], timeout: 600).status == 0 else { throw Failure(String(localized: "Kopieren fehlgeschlagen", bundle: .module)) }

        progress(String(localized: "Ersetze \(update.app.name) …", bundle: .module))
        let target = URL(fileURLWithPath: update.app.path)
        let report = Uninstaller.run(
            [UninstallPlan(app: update.app, leftovers: [])], privilegedTrash: privilegedTrash)
        guard report.removedApps.count == 1 else {
            throw Failure(report.failures.first?.reason ?? String(localized: "Alte Version ließ sich nicht entfernen", bundle: .module))
        }
        do {
            try FileManager.default.moveItem(at: staged, to: target)
        } catch {
            throw Failure(String(localized: "Neue Version konnte nicht abgelegt werden, die alte liegt im Papierkorb: \(error.localizedDescription)", bundle: .module))
        }
        let installedVersion = (Bundle(url: target)?.infoDictionary?["CFBundleShortVersionString"] as? String) ?? update.available
        return .installed(installedVersion)
    }

    enum Kind { case dmg, zip, tar, pkg }

    static func detect(_ file: URL) throws -> Kind {
        let ext = file.pathExtension.lowercased()
        let head = (try? FileHandle(forReadingFrom: file).read(upToCount: 8)) ?? Data()
        if head.starts(with: [0x50, 0x4B, 0x03, 0x04]) || ext == "zip" { return .zip }
        if head.starts(with: Array("xar!".utf8)) || ext == "pkg" || ext == "mpkg" { return .pkg }
        if ext == "dmg" { return .dmg }
        if ["gz", "tgz", "xz", "bz2", "tar"].contains(ext) { return .tar }
        if Shell.run("/usr/bin/hdiutil", ["imageinfo", file.path], timeout: 30).status == 0 { return .dmg }
        throw Failure(String(localized: "Unbekanntes Download-Format", bundle: .module))
    }

    static func sha256(of file: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: file)
        defer { try? h.close() }
        var hasher = SHA256()
        while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Top-most .app (up to three levels deep) with the expected bundle id.
    static func findApp(in root: URL, bundleID: String) -> URL? {
        var queue: [(URL, Int)] = [(root, 0)]
        while !queue.isEmpty {
            let (dir, depth) = queue.removeFirst()
            for child in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                if child.pathExtension == "app" {
                    if Bundle(url: child)?.bundleIdentifier == bundleID { return child }
                } else if depth < 3, DirectoryScanner.isDirectory(child.path) {
                    queue.append((child, depth + 1))
                }
            }
        }
        return nil
    }

    /// Valid signature, same team as the installed copy, and accepted by Gatekeeper (notarized).
    static func verifySameDeveloper(new: String, installed: String) throws {
        guard let newTeam = signature(new) else { throw Failure(String(localized: "Neue Version ist nicht gültig signiert", bundle: .module)) }
        // The installed copy may have been touched by its own updater; only its developer matters here.
        let oldTeam = signature(installed, requireValid: false)
        if let old = oldTeam?.team, newTeam.team != old {
            let other = newTeam.team ?? "?"
            throw Failure(String(localized: "Neue Version stammt von einem anderen Entwickler (\(other) statt \(old))", bundle: .module))
        }
        let assess = Shell.run("/usr/sbin/spctl", ["--assess", "--type", "execute", new], timeout: 60)
        guard assess.status == 0 else { throw Failure(String(localized: "Gatekeeper lehnt die neue Version ab", bundle: .module)) }
    }

    static func verifyPackage(_ pkg: URL) throws {
        let r = Shell.run("/usr/sbin/pkgutil", ["--check-signature", pkg.path], timeout: 60)
        guard r.status == 0, r.output.contains("Developer ID Installer") || r.output.contains("Apple") else {
            throw Failure(String(localized: "Installationspaket ist nicht vertrauenswürdig signiert", bundle: .module))
        }
    }

    /// Team identifier of a validly signed bundle (nil team for ad-hoc), or nil when the signature is broken.
    static func signature(_ path: String, requireValid: Bool = true) -> (team: String?, valid: Bool)? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        let valid = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil) == errSecSuccess
        if requireValid && !valid { return nil }
        var dict: CFDictionary?
        SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &dict)
        let team = (dict as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
        return (team, valid)
    }
}
