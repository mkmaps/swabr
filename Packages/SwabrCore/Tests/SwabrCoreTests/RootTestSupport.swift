import Foundation
@testable import SwabrCore

/// Stand-in for the helper: carries out the operations as the current user, with the helper's own checks.
/// `roots` adds folders the fake system lives in; `before` lifts a lock the user could not get past.
func rootAsUser(home: String, roots: [String] = [], before: @escaping @Sendable () -> Void = {}) -> RootRunner {
    var executor = RootExecutor(uid: getuid(), gid: getgid(), home: home, timeout: 30)
    executor.sourceRoots += roots
    let e = executor
    return { ops in
        before()
        return e.perform(ops)
    }
}
