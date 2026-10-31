import Darwin
import Foundation

public enum DiskSize {
    /// Allocated bytes of a file or directory tree. Symlinks are counted, never followed.
    public static func allocatedSize(of path: String) -> Int64 {
        var st = stat()
        guard lstat(path, &st) == 0 else { return 0 }
        guard (st.st_mode & S_IFMT) == S_IFDIR else { return Int64(st.st_blocks) * 512 }

        var total = Int64(st.st_blocks) * 512
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey]
        guard let e = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }
        ) else { return total }
        for case let child as URL in e {
            let v = try? child.resourceValues(forKeys: Set(keys))
            total += Int64(v?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// "0 KB" rather than the spelled-out "Zero KB" some languages get by default.
    public static func format(_ bytes: Int64) -> String { format(bytes, style: .file) }

    public static func format(_ bytes: Int64, style: ByteCountFormatter.CountStyle) -> String {
        let f = ByteCountFormatter()
        f.countStyle = style
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: bytes)
    }
}

public enum VolumeInfo {
    public static func freeSpace(at path: String = UserHome.path) -> Int64? {
        let v = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return v?.volumeAvailableCapacityForImportantUsage
    }

    /// Bytes in use on the volume (total minus actually free, without purgeable space).
    public static func usedSpace(at path: String = UserHome.path) -> Int64? {
        guard let v = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = v.volumeTotalCapacity, let free = v.volumeAvailableCapacity else { return nil }
        return Int64(total) - Int64(free)
    }

    public static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }
}
