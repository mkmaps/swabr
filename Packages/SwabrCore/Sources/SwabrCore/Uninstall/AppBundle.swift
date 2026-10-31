import Foundation

/// The two layouts an app in /Applications can have: a Mac app (`Foo.app/Contents/Info.plist`) or an
/// iPhone/iPad app running on Apple silicon, which the App Store installs as a wrapper
/// (`Foo.app/Wrapper/Inner.app/Info.plist`, metadata in `Foo.app/Wrapper/iTunesMetadata.plist`).
public enum AppBundle {
    /// The app's Info.plist, in whichever layout it has.
    public static func infoPlistURL(_ path: String) -> URL? {
        let mac = URL(fileURLWithPath: path).appending(path: "Contents/Info.plist")
        if FileManager.default.fileExists(atPath: mac.path) { return mac }
        guard let inner = wrappedApp(path) else { return nil }
        let ios = URL(fileURLWithPath: inner).appending(path: "Info.plist")
        return FileManager.default.fileExists(atPath: ios.path) ? ios : nil
    }

    public static func info(_ path: String) -> [String: Any] {
        guard let url = infoPlistURL(path), let data = try? Data(contentsOf: url) else { return [:] }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]) ?? [:]
    }

    /// The real app inside an iPhone/iPad wrapper, or nil for a Mac app.
    public static func wrappedApp(_ path: String) -> String? {
        let wrapper = path + "/Wrapper"
        guard let inner = (try? FileManager.default.contentsOfDirectory(atPath: wrapper))?.first(where: { $0.hasSuffix(".app") })
        else { return nil }
        return wrapper + "/" + inner
    }

    public static func isIOSApp(_ path: String) -> Bool { wrappedApp(path) != nil }

    /// Part of macOS: protected by System Integrity Protection ("restricted" flag) or a link into the
    /// system volume, as Safari is in /Applications. Such an item can't be removed by anyone.
    public static func isSystemProtected(_ path: String) -> Bool {
        var st = stat()
        guard lstat(path, &st) == 0 else { return false }
        if st.st_flags & UInt32(SF_RESTRICTED) != 0 { return true }
        if (st.st_mode & S_IFMT) == S_IFLNK,
           let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
            let resolved = URL(fileURLWithPath: dest, relativeTo: URL(fileURLWithPath: path).deletingLastPathComponent()).standardizedFileURL.path
            return resolved.hasPrefix("/System/")
        }
        return false
    }

    /// Installed from the App Store: a Mac receipt or the wrapper's store metadata.
    public static func isFromAppStore(_ path: String) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: path + "/Contents/_MASReceipt/receipt")
            || fm.fileExists(atPath: path + "/Wrapper/iTunesMetadata.plist")
    }
}
