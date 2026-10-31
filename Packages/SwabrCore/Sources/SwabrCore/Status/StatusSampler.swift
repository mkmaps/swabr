import Darwin
import Foundation
import IOKit
import IOKit.ps
import SystemConfiguration

/// Takes live readings of the machine. Rates (CPU, disk, network, per-process CPU) come from the
/// difference to the previous call, so the first `sample()` reports them as zero.
///
/// Everything degrades quietly: in the sandbox, or when a source is missing, the affected values
/// stay at zero, nil or empty instead of failing.
public final class StatusSampler: @unchecked Sendable {
    private let lock = NSLock()
    private let host = mach_host_self()
    private let store = SCDynamicStoreCreate(nil, "Swabr.Status" as CFString, nil, nil)
    private let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    private var lastTime: UInt64?
    private var lastCoreTicks: [CoreTicks] = []
    private var cpuWindow: [(time: UInt64, usage: Double)] = []
    private var lastDisk: (read: UInt64, write: UInt64)?
    private var lastNet: (interface: String, rx: UInt32, tx: UInt32)?
    private var downSmoother = RateSmoother()
    private var upSmoother = RateSmoother()
    private var lastProcessTimes: [Int32: UInt64] = [:]
    private var batteryDetails: BatteryDetails?
    private var batteryDetailsTime: UInt64?
    private var proxy: (value: String?, time: UInt64)?

    /// IORegistry battery details change slowly; re-read them at most this often.
    private static let batteryDetailsInterval: UInt64 = 60 * 1_000_000_000
    private static let proxyInterval: UInt64 = 10 * 1_000_000_000
    private static let cpuWindowLength: UInt64 = 60 * 1_000_000_000

    public init() {
        ModelName.prefetch()
    }

    public func sample() -> StatusSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let elapsed = lastTime.map { Double(now &- $0) / 1e9 } ?? 0
        lastTime = now

        let hardware = readHardware()
        let cpu = readCPU(now: now)
        let memory = readMemory(total: hardware.memoryBytes)
        let disk = readDisk(elapsed: elapsed)
        let battery = readBattery(now: now)
        let network = readNetwork(elapsed: elapsed, now: now)
        let processes = readProcesses(elapsed: elapsed)

        let health = HealthScore.compute(
            diskFree: disk.total > 0 ? disk.free : nil,
            diskTotal: disk.total > 0 ? disk.total : nil,
            pressure: memory.pressure,
            swapUsed: memory.swapUsed,
            cpuMinuteAverage: cpu.minuteAverage,
            battery: battery?.health.severity ?? .unknown,
            uptime: hardware.uptime,
            zombies: processes.zombies.count
        )
        return StatusSnapshot(date: Date(), hardware: hardware, cpu: cpu, memory: memory, disk: disk,
                              battery: battery, network: network, processes: processes, health: health)
    }

    // MARK: Hardware

    private func readHardware() -> StatusSnapshot.Hardware {
        let identifier = Sysctl.string("hw.model") ?? "Mac"
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let os = "macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : "")
        var uptime: TimeInterval = 0
        if let boot = Sysctl.value("kern.boottime", timeval()) {
            uptime = max(0, Date().timeIntervalSince1970 - (Double(boot.tv_sec) + Double(boot.tv_usec) / 1e6))
        }
        return .init(model: ModelName.cached ?? identifier, modelIdentifier: identifier,
                     chip: Sysctl.string("machdep.cpu.brand_string") ?? "",
                     memoryBytes: Sysctl.value("hw.memsize", UInt64(0)) ?? 0,
                     osVersion: os, uptime: uptime)
    }

    // MARK: CPU

    struct CoreTicks: Equatable {
        var busy: UInt32
        var idle: UInt32
    }

    private func readCPU(now: UInt64) -> StatusSnapshot.CPU {
        let ticks = coreTicks()
        var perCore = [Double](repeating: 0, count: ticks.count)
        var usage = 0.0
        if lastCoreTicks.count == ticks.count, !ticks.isEmpty {
            var busySum: UInt64 = 0, allSum: UInt64 = 0
            for i in ticks.indices {
                // Tick counters are 32 bit and wrap; wrapping subtraction keeps the difference right.
                let busy = UInt64(ticks[i].busy &- lastCoreTicks[i].busy)
                let idle = UInt64(ticks[i].idle &- lastCoreTicks[i].idle)
                perCore[i] = busy + idle > 0 ? Double(busy) / Double(busy + idle) * 100 : 0
                busySum += busy
                allSum += busy + idle
            }
            usage = allSum > 0 ? Double(busySum) / Double(allSum) * 100 : 0
            cpuWindow.append((now, usage))
        }
        lastCoreTicks = ticks
        cpuWindow.removeAll { now &- $0.time > Self.cpuWindowLength }
        let average = cpuWindow.isEmpty ? 0 : cpuWindow.map(\.usage).reduce(0, +) / Double(cpuWindow.count)

        var load = [Double](repeating: 0, count: 3)
        if getloadavg(&load, 3) != 3 { load = [0, 0, 0] }
        return .init(usage: usage, perCore: perCore, load: (load[0], load[1], load[2]), minuteAverage: average)
    }

    private func coreTicks() -> [CoreTicks] {
        var cores: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cores, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(cores)).map { core in
            func t(_ state: Int32) -> UInt32 { UInt32(bitPattern: info[core * stride + Int(state)]) }
            return CoreTicks(busy: t(CPU_STATE_USER) &+ t(CPU_STATE_SYSTEM) &+ t(CPU_STATE_NICE), idle: t(CPU_STATE_IDLE))
        }
    }

    // MARK: Memory

    struct MemoryFigures: Equatable {
        var used: UInt64
        var available: UInt64
        var wired: UInt64
        var compressed: UInt64
        var cached: UInt64
    }

    /// Used = active + wired + compressed; available = total − used; cache = inactive + speculative +
    /// file-backed, but never more than is actually available.
    static func memoryFigures(_ vm: vm_statistics64, pageSize: UInt64, total: UInt64) -> MemoryFigures {
        let active = UInt64(vm.active_count) * pageSize
        let wired = UInt64(vm.wire_count) * pageSize
        let compressed = UInt64(vm.compressor_page_count) * pageSize
        let used = min(total, active + wired + compressed)
        let available = total - used
        let cache = (UInt64(vm.inactive_count) + UInt64(vm.speculative_count) + UInt64(vm.external_page_count)) * pageSize
        return .init(used: used, available: available, wired: wired, compressed: compressed, cached: min(cache, available))
    }

    private func readMemory(total: UInt64) -> StatusSnapshot.Memory {
        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        let pageSize = UInt64(Sysctl.value("hw.pagesize", Int(0)) ?? Int(getpagesize()))
        let figures = result == KERN_SUCCESS
            ? Self.memoryFigures(vm, pageSize: pageSize, total: total)
            : MemoryFigures(used: 0, available: total, wired: 0, compressed: 0, cached: 0)
        let swap = Sysctl.value("vm.swapusage", xsw_usage())
        let level = Sysctl.value("kern.memorystatus_vm_pressure_level", Int32(1)) ?? 1
        return .init(total: total, used: figures.used, available: figures.available, wired: figures.wired,
                     compressed: figures.compressed, cached: figures.cached,
                     swapUsed: swap?.xsu_used ?? 0, swapTotal: swap?.xsu_total ?? 0,
                     pressure: .init(level: Int(level)))
    }

    // MARK: Disk

    private func readDisk(elapsed: Double) -> StatusSnapshot.Disk {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys)
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let free = values?.volumeAvailableCapacityForImportantUsage ?? 0

        var readRate = 0.0, writeRate = 0.0
        if let now = Self.blockStorageBytes() {
            if let last = lastDisk, elapsed > 0 {
                // A counter that went backwards (disk detached) gives no rate this round.
                readRate = now.read >= last.read ? Double(now.read - last.read) / elapsed : 0
                writeRate = now.write >= last.write ? Double(now.write - last.write) / elapsed : 0
            }
            lastDisk = now
        }
        return .init(total: total, free: free, readRate: readRate, writeRate: writeRate)
    }

    /// Sum of the byte counters of all block storage drivers.
    private static func blockStorageBytes() -> (read: UInt64, write: UInt64)? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, write: UInt64 = 0, found = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            read &+= (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            write &+= (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            found = true
        }
        return found ? (read, write) : nil
    }

    // MARK: Battery

    struct BatteryDetails: Equatable {
        var cycles: Int
        var capacityPercent: Int
        var temperature: Double?
    }

    private func readBattery(now: UInt64) -> StatusSnapshot.Battery? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let source = list.lazy
            .compactMap { IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { $0["Type"] as? String == "InternalBattery" }
        guard let d = source else { return nil }

        if batteryDetailsTime.map({ now &- $0 > Self.batteryDetailsInterval }) ?? true {
            batteryDetails = Self.readSmartBattery()
            batteryDetailsTime = now
        }

        let current = d["Current Capacity"] as? Int ?? 0
        let max = d["Max Capacity"] as? Int ?? 100
        let charging = d["Is Charging"] as? Bool ?? false
        let minutes = (charging ? d["Time to Full Charge"] : d["Time to Empty"]) as? Int
        return .init(level: max > 0 ? Swift.min(100, current * 100 / max) : current,
                     isCharging: charging,
                     onACPower: d["Power Source State"] as? String == "AC Power",
                     isCharged: d["Is Charged"] as? Bool ?? false,
                     minutesRemaining: minutes.flatMap { $0 > 0 ? $0 : nil },
                     cycles: batteryDetails?.cycles ?? 0,
                     healthPercent: batteryDetails?.capacityPercent ?? 0,
                     temperature: batteryDetails?.temperature)
    }

    /// Full-charge capacity in percent of design capacity. Raw mAh values win; a "MaxCapacity" of
    /// 100 or less is already a percentage (Apple silicon reports it that way).
    static func capacityPercent(rawMax: Int?, max: Int?, design: Int?) -> Int {
        if let design, design > 0 {
            if let rawMax, rawMax > 0 { return Int((Double(rawMax) / Double(design) * 100).rounded(.down)) }
            if let max, max > 100 { return Int((Double(max) / Double(design) * 100).rounded(.down)) }
        }
        if let max, max > 0, max <= 100 { return max }
        return 0
    }

    /// Reads AppleSmartBattery. Depending on the macOS version the values sit on the node itself, in its
    /// "BatteryData" dictionary, or on a child node, so all of those are searched in that order.
    private static func readSmartBattery() -> BatteryDetails? {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }

        let wanted = ["CycleCount", "DesignCapacity", "AppleRawMaxCapacity", "MaxCapacity", "Temperature"]
        var sources: [[String: Any]] = []
        func collect(_ entry: io_registry_entry_t) {
            var own: [String: Any] = [:]
            for key in wanted + ["BatteryData"] {
                own[key] = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            sources.append(own)
            if let data = own["BatteryData"] as? [String: Any] { sources.append(data) }
        }
        collect(root)
        var iterator: io_iterator_t = 0
        if IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS {
            while case let child = IOIteratorNext(iterator), child != 0 {
                collect(child)
                IOObjectRelease(child)
            }
            IOObjectRelease(iterator)
        }
        func int(_ key: String) -> Int? { sources.lazy.compactMap { ($0[key] as? NSNumber)?.intValue }.first }

        // Temperature is reported in hundredths of a degree Celsius.
        let temperature = int("Temperature").flatMap { $0 > 0 ? Double($0) / 100 : nil }
        return .init(cycles: int("CycleCount") ?? 0,
                     capacityPercent: capacityPercent(rawMax: int("AppleRawMaxCapacity"), max: int("MaxCapacity"), design: int("DesignCapacity")),
                     temperature: temperature)
    }

    // MARK: Network

    /// Moving average over the last few values, so a single burst does not make the graph jump.
    struct RateSmoother {
        var window = 3
        private(set) var values: [Double] = []

        mutating func add(_ value: Double) -> Double {
            values.append(value)
            if values.count > window { values.removeFirst(values.count - window) }
            return values.reduce(0, +) / Double(values.count)
        }

        mutating func reset() { values.removeAll() }
    }

    private struct InterfaceInfo {
        var address: String?
        var rx: UInt32?
        var tx: UInt32?
        var usable = false
    }

    private func readNetwork(elapsed: Double, now: UInt64) -> StatusSnapshot.Network {
        let interfaces = Self.interfaces()
        var primary: String?
        if let store, let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] {
            primary = global["PrimaryInterface"] as? String
        }
        // Without the dynamic store (sandbox), take the first active interface with an IPv4 address.
        if primary == nil {
            primary = interfaces.filter { $0.value.usable && $0.value.address != nil }.keys.sorted().first
        }

        var down = 0.0, up = 0.0
        if let name = primary, let info = interfaces[name], let rx = info.rx, let tx = info.tx {
            if let last = lastNet, last.interface == name, elapsed > 0 {
                // if_data counters are 32 bit; wrapping subtraction survives one overflow per interval.
                down = downSmoother.add(Double(rx &- last.rx) / elapsed)
                up = upSmoother.add(Double(tx &- last.tx) / elapsed)
            } else {
                downSmoother.reset()
                upSmoother.reset()
            }
            lastNet = (name, rx, tx)
        } else {
            lastNet = nil
            downSmoother.reset()
            upSmoother.reset()
        }

        if proxy.map({ now &- $0.time > Self.proxyInterval }) ?? true {
            let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
            proxy = (settings.flatMap(Self.proxyDescription), now)
        }
        return .init(interface: primary, address: primary.flatMap { interfaces[$0]?.address },
                     downRate: down, upRate: up, proxy: proxy?.value)
    }

    private static func interfaces() -> [String: InterfaceInfo] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [:] }
        defer { freeifaddrs(head) }
        var result: [String: InterfaceInfo] = [:]
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = entry.pointee
            guard let addr = ifa.ifa_addr else { continue }
            let flags = Int32(ifa.ifa_flags)
            guard flags & IFF_LOOPBACK == 0 else { continue }
            let name = String(cString: ifa.ifa_name)
            var info = result[name] ?? InterfaceInfo()
            info.usable = flags & IFF_UP != 0 && flags & IFF_RUNNING != 0
            switch Int32(addr.pointee.sa_family) {
            case AF_LINK:
                if let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                    info.rx = data.ifi_ibytes
                    info.tx = data.ifi_obytes
                }
            case AF_INET where info.address == nil:
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    info.address = String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                }
            default:
                break
            }
            result[name] = info
        }
        return result
    }

    /// Short description of the system proxy, nil when none is set. Secure web proxy first, then
    /// web, then SOCKS; automatic configuration only when no fixed proxy is set.
    static func proxyDescription(_ settings: [String: Any]) -> String? {
        func enabled(_ key: String) -> Bool { (settings[key] as? NSNumber)?.boolValue ?? false }
        for kind in ["HTTPS", "HTTP", "SOCKS"] where enabled(kind + "Enable") {
            guard let host = settings[kind + "Proxy"] as? String, !host.isEmpty else { continue }
            let port = (settings[kind + "Port"] as? NSNumber)?.intValue
            return port.map { "\(host):\($0)" } ?? host
        }
        if enabled("ProxyAutoConfigEnable") || enabled("ProxyAutoDiscoveryEnable") {
            return String(localized: "Automatisch (PAC)", bundle: .module)
        }
        return nil
    }

    // MARK: Processes

    private static let topCount = 5

    private func readProcesses(elapsed: Double) -> StatusSnapshot.Processes {
        let all = Self.processTable()
        var times: [Int32: UInt64] = [:]
        var candidates: [StatusSnapshot.Processes.Process] = []
        var zombies: [StatusSnapshot.Processes.Process] = []

        for entry in all {
            if entry.isZombie {
                zombies.append(.init(pid: entry.pid, name: entry.name, cpu: 0, memory: 0))
                continue
            }
            // Processes that cannot be read (other users, sandbox) are left out of the ranking.
            var usage = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(entry.pid, RUSAGE_INFO_V2, $0) }
            }
            guard ok == 0 else { continue }
            let cpuTime = toNanoseconds(usage.ri_user_time &+ usage.ri_system_time)
            times[entry.pid] = cpuTime
            var cpu = 0.0
            if elapsed > 0, let last = lastProcessTimes[entry.pid], cpuTime >= last {
                cpu = Double(cpuTime - last) / (elapsed * 1e9) * 100
            }
            candidates.append(.init(pid: entry.pid, name: entry.name, cpu: cpu, memory: usage.ri_phys_footprint))
        }
        lastProcessTimes = times

        let top = candidates
            .sorted { $0.cpu != $1.cpu ? $0.cpu > $1.cpu : $0.memory > $1.memory }
            .prefix(Self.topCount)
            .map { p -> StatusSnapshot.Processes.Process in
                var p = p
                p.name = Self.processName(p.pid) ?? p.name
                return p
            }
        return .init(count: all.count, top: top, zombies: zombies)
    }

    private func toNanoseconds(_ ticks: UInt64) -> UInt64 {
        guard timebase.denom > 0, timebase.numer != timebase.denom else { return ticks }
        return UInt64(Double(ticks) * Double(timebase.numer) / Double(timebase.denom))
    }

    private struct ProcessEntry {
        var pid: Int32
        var name: String
        var isZombie: Bool
    }

    /// All processes from `kern.proc.all`, with their short command names and run state.
    private static func processTable() -> [ProcessEntry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return [] }
        // The table can grow between the two calls.
        size += size / 8
        let stride = MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
        guard sysctl(&mib, u_int(mib.count), &procs, &size, nil, 0) == 0 else { return [] }
        return procs.prefix(size / stride).map { kp in
            var comm = kp.kp_proc.p_comm
            let name = withUnsafeBytes(of: &comm) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            return ProcessEntry(pid: kp.kp_proc.p_pid, name: name, isZombie: Int32(kp.kp_proc.p_stat) == SZOMB)
        }
    }

    private static func processName(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let name = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return name.isEmpty ? nil : name
    }

    /// Parses `ps -axo pid=,%cpu=,rss=,state=,comm=` output (rss in KiB, decimal comma accepted).
    /// Not used for sampling; kept for diagnostics and comparison with the live reading.
    public static func parsePS(_ text: String) -> StatusSnapshot.Processes {
        var all: [StatusSnapshot.Processes.Process] = []
        var zombies: [StatusSnapshot.Processes.Process] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard fields.count == 5, let pid = Int32(fields[0]),
                  let cpu = Double(fields[1].replacingOccurrences(of: ",", with: ".")),
                  let rss = UInt64(fields[2]) else { continue }
            let process = StatusSnapshot.Processes.Process(pid: pid, name: String(fields[4]).trimmingCharacters(in: .whitespaces),
                                                           cpu: cpu, memory: rss * 1024)
            if fields[3].hasPrefix("Z") { zombies.append(process) } else { all.append(process) }
        }
        let top = all.sorted { $0.cpu > $1.cpu }.prefix(topCount)
        return .init(count: all.count + zombies.count, top: Array(top), zombies: zombies)
    }
}

// MARK: - Helpers

enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let text = String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// Reads a fixed-size plain value (integers, C structs without pointers).
    static func value<T: BitwiseCopyable>(_ name: String, _ initial: T) -> T? {
        var value = initial
        var size = MemoryLayout<T>.size
        let ok = withUnsafeMutableBytes(of: &value) { sysctlbyname(name, $0.baseAddress, &size, nil, 0) == 0 }
        return ok ? value : nil
    }
}

/// The readable model name costs a `system_profiler` run (about a second), so it is fetched once in the
/// background and cached for the life of the process. Until then, and if it fails, callers use `hw.model`.
enum ModelName {
    private static let state = LockedState()

    private final class LockedState: @unchecked Sendable {
        let lock = NSLock()
        var name: String?
        var started = false
    }

    static var cached: String? {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.name
    }

    static func prefetch() {
        state.lock.lock()
        let start = !state.started
        state.started = true
        state.lock.unlock()
        guard start else { return }
        DispatchQueue.global(qos: .utility).async {
            let name = fetch()
            state.lock.lock()
            state.name = name
            state.lock.unlock()
        }
    }

    private static func fetch() -> String? {
        let tool = "/usr/sbin/system_profiler"
        guard FileManager.default.isExecutableFile(atPath: tool) else { return nil }
        // ToolRun waits through a termination handler; waitUntilExit can miss the exit off the main run loop.
        guard case .exited(0, let data) = ToolRun.run(tool, ["SPHardwareDataType", "-json"], timeout: 30) else { return nil }
        return parse(data)
    }

    /// Reads "machine_name" from `system_profiler SPHardwareDataType -json`.
    static func parse(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["SPHardwareDataType"] as? [[String: Any]],
              let name = items.first?["machine_name"] as? String, !name.isEmpty else { return nil }
        return name
    }
}
