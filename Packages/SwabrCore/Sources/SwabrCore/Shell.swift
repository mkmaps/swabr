import Foundation

/// Runs a command-line tool and returns its exit status and everything it printed (standard output and
/// standard error together, so error lines of tools like brew reach the caller). For callers that must
/// tell a timeout from a failure, `ToolRun` is the finer tool.
enum Shell {
    private final class Collected: @unchecked Sendable {
        var data = Data()
    }

    /// Status -1 when the tool could not start or ran past `timeout` (it is then terminated).
    @discardableResult
    static func run(_ path: String, _ args: [String], timeout: TimeInterval = 60) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return (-1, "") }

        // Drained while the tool runs, so a full pipe never stalls it. A thread of its own, not the shared
        // dispatch pool: the read blocks, and many parallel calls would otherwise starve every other task.
        let collected = Collected()
        let drained = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            collected.data = pipe.fileHandleForReading.readDataToEndOfFile()
            drained.signal()
        }

        guard finished.wait(timeout: .now() + max(0, timeout)) == .success else {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            _ = drained.wait(timeout: .now() + 1)
            return (-1, String(decoding: collected.data, as: UTF8.self))
        }
        // A child the tool left behind may keep the pipe open; do not wait for it forever.
        _ = drained.wait(timeout: .now() + 2)
        return (process.terminationStatus, String(decoding: collected.data, as: UTF8.self))
    }
}
