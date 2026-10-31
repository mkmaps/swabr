import Foundation

/// Swabr's privileged helper. launchd starts it on demand as root; it serves the Mach service named in its
/// launchd plist and accepts connections only from the Swabr app signed by the same team.
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

    func run(_ script: String, reply: @escaping (Int32, String) -> Void) {
        touch()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
        let pipe = Pipe()
        // Standard output only, as `do shell script` returns it: callers parse it line by line.
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        // A termination handler, not waitUntilExit: that can miss the exit off the main run loop.
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch {
            reply(-1, error.localizedDescription)
            return
        }
        // Read on a thread of its own so a full pipe never stalls the script.
        let output = Output()
        let drained = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            output.data = pipe.fileHandleForReading.readDataToEndOfFile()
            drained.signal()
        }
        exited.wait()
        _ = drained.wait(timeout: .now() + 5)
        touch()
        reply(process.terminationStatus, String(decoding: output.data, as: UTF8.self))
    }

    func version(reply: @escaping (String) -> Void) {
        touch()
        reply(HelperIdentity.version)
    }

    private final class Output: @unchecked Sendable {
        var data = Data()
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

let helper = Helper()
let listener = NSXPCListener(machServiceName: HelperIdentity.machService)
listener.delegate = helper
listener.resume()
helper.exitWhenIdle()
RunLoop.main.run()
