import Foundation

/// Swabr's privileged helper. It runs as root in two ways and accepts nothing but fixed `RootOperation`s,
/// each checked again here (`RootExecutor`), never a script:
/// - launchd starts it on demand for the Mach service in its launchd plist; it then accepts connections only
///   from Swabr OP signed by the same team and works for the user of the connecting process;
/// - after the macOS password prompt (no helper set up) the app runs it once with
///   `--perform <base64 request> --uid <uid>` and reads the base64 results from standard output.
final class Helper: NSObject, NSXPCListenerDelegate, SwabrHelperProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var lastUse = Date()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(HelperIdentity.appRequirement)
        connection.exportedInterface = NSXPCInterface(with: SwabrHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func perform(_ request: Data, reply: @escaping (Data) -> Void) {
        touch()
        // The work is done for the user of the connecting app, not for a user id the request names.
        let uid = NSXPCConnection.current()?.effectiveUserIdentifier ?? 0
        reply(Self.handle(request, uid: uid))
        touch()
    }

    func version(reply: @escaping (String) -> Void) {
        touch()
        reply(HelperIdentity.version)
    }

    /// Decodes, checks and carries out a request; empty data for an unreadable request or an unknown user.
    static func handle(_ request: Data, uid: uid_t) -> Data {
        guard let decoded = try? JSONDecoder().decode(RootRequest.self, from: request),
              let executor = RootExecutor.forUser(uid) else { return Data() }
        return (try? JSONEncoder().encode(executor.perform(decoded.operations))) ?? Data()
    }

    private func touch() { lock.withLock { lastUse = Date() } }

    /// launchd restarts the helper on the next request, so it leaves after a few idle minutes.
    func exitWhenIdle() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [self] in
            if lock.withLock({ Date().timeIntervalSince(lastUse) }) > 300 { exit(0) }
        }
        timer.resume()
        idleTimer = timer
    }

    private var idleTimer: DispatchSourceTimer?
}

let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--perform"), i + 1 < arguments.count,
   let j = arguments.firstIndex(of: "--uid"), j + 1 < arguments.count, let uid = uid_t(arguments[j + 1]),
   let request = Data(base64Encoded: arguments[i + 1]) {
    // One-off run after the password prompt: only as root, and never on behalf of root.
    guard getuid() == 0 || geteuid() == 0, uid != 0 else { exit(64) }
    print(Helper.handle(request, uid: uid).base64EncodedString())
    exit(0)
}

let helper = Helper()
let listener = NSXPCListener(machServiceName: HelperIdentity.machService)
listener.delegate = helper
listener.resume()
helper.exitWhenIdle()
RunLoop.main.run()
