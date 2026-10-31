import Foundation

/// The XPC interface of Swabr's privileged helper (Direct edition). Shared by the app and the helper.
@objc protocol SwabrHelperProtocol {
    /// Runs `script` with /bin/sh as root; replies with the exit status and its standard output.
    func run(_ script: String, reply: @escaping (Int32, String) -> Void)
    /// Lets the app tell an outdated helper from the current one.
    func version(reply: @escaping (String) -> Void)
}

enum HelperIdentity {
    static let machService = "io.github.mkmaps.swabr.helper"
    static let plistName = "io.github.mkmaps.swabr.helper.plist"
    /// Bumped whenever the helper's behaviour changes, so the app re-registers it.
    static let version = "1"
    /// Only Swabr itself, signed by this team, may talk to the helper, and the app talks only to that helper.
    static let team = "Y94QZAZZ45"
    static let appRequirement = "anchor apple generic and identifier \"io.github.mkmaps.swabr\" and certificate leaf[subject.OU] = \"\(team)\""
    static let helperRequirement = "anchor apple generic and identifier \"io.github.mkmaps.swabr.helper\" and certificate leaf[subject.OU] = \"\(team)\""
}
