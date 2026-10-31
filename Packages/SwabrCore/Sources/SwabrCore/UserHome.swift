import Darwin
import Foundation

/// The user's real home folder. Inside the App Store sandbox `NSHomeDirectory()` points into the app's
/// container, so everything that looks at the user's files goes through this instead.
public enum UserHome {
    public static let path: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }()
}
