import Darwin
import Foundation

/// What running processes are doing in the file system, read straight from the kernel (libproc).
public enum Processes {
    /// The current working directory of every process this user may inspect. Processes of other
    /// users (and ones that exit while we look) are left out.
    public static func workingDirectories() -> [String] {
        let all = UInt32(PROC_ALL_PIDS)
        let needed = proc_listpids(all, 0, nil, 0)
        guard needed > 0 else { return [] }
        // Some room for processes started between the two calls.
        var pids = [pid_t](repeating: 0, count: Int(needed) / MemoryLayout<pid_t>.stride + 64)
        let filled = pids.withUnsafeMutableBytes { proc_listpids(all, 0, $0.baseAddress, Int32($0.count)) }
        guard filled > 0 else { return [] }
        var out = Set<String>()
        for pid in pids.prefix(Int(filled) / MemoryLayout<pid_t>.stride) where pid > 0 {
            if let cwd = workingDirectory(of: pid) { out.insert(cwd) }
        }
        return out.sorted()
    }

    /// True when one of the directories is `folder` itself or lies below it.
    public static func isInUse(_ folder: String, workingDirectories: [String]) -> Bool {
        let base = folder.count > 1 && folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        let below = base == "/" ? "/" : base + "/"
        return workingDirectories.contains { $0 == base || $0.hasPrefix(below) }
    }

    /// Same check against the processes running right now.
    public static func isInUse(_ folder: String) -> Bool {
        isInUse(folder, workingDirectories: workingDirectories())
    }

    static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.hasPrefix("/") ? path : nil
    }
}

/// Runs a helper tool with a deadline and collects its standard output.
enum ToolRun {
    enum Outcome: Sendable {
        case exited(status: Int32, output: Data)
        case timedOut
        /// The tool could not be started.
        case failed
    }

    private final class Output: @unchecked Sendable {
        var data = Data()
    }

    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval,
                    environment: [String: String]? = nil) -> Outcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return .failed }

        // Read while the tool runs, so a full pipe never blocks it.
        let output = Output()
        let reading = DispatchGroup()
        reading.enter()
        // A thread of its own: the read blocks, and the shared dispatch pool must stay free for other work.
        Thread.detachNewThread {
            output.data = pipe.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }

        let deadline = DispatchTime.now() + max(0, timeout)
        guard exited.wait(timeout: deadline) == .success else {
            process.terminate()
            if exited.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            return .timedOut
        }
        // A grandchild could still hold the pipe open.
        guard reading.wait(timeout: .now() + 2) == .success else { return .timedOut }
        return .exited(status: process.terminationStatus, output: output.data)
    }
}
