import Foundation
import ServiceManagement

/// Swabr's privileged helper (Direct edition only): approved once in System Settings → Login Items, then
/// administrator steps run without a password prompt. Without it, `Privileged.run` asks for the password.
enum PrivilegedHelper {
    enum State: Equatable {
        case notInstalled, needsApproval, enabled, unavailable
    }

    private static var service: SMAppService { .daemon(plistName: HelperIdentity.plistName) }

    static var state: State {
        guard !Edition.isStore else { return .unavailable }
        switch service.status {
        case .enabled: return .enabled
        case .requiresApproval: return .needsApproval
        case .notRegistered, .notFound: return .notInstalled
        @unknown default: return .notInstalled
        }
    }

    /// Registers the helper; macOS then asks the user to allow it under Login Items.
    /// Until the user allows it, `register()` fails with "Operation not permitted" although the helper is
    /// registered and waiting for approval; that case just leads on to System Settings.
    static func install() throws {
        do {
            try service.register()
        } catch {
            guard service.status == .requiresApproval || (error as NSError).code == kSMErrorLaunchDeniedByUser else { throw error }
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    static func uninstall() throws {
        try service.unregister()
    }

    static func openApproval() { SMAppService.openSystemSettingsLoginItems() }

    private final class Result: @unchecked Sendable {
        var status: Int32 = -1
        var output = ""
        var reached = false
    }

    /// Runs `script` as root through the helper. Nil when the helper is not enabled or could not be reached,
    /// so the caller can fall back to the password prompt.
    static func run(_ script: String, timeout: TimeInterval = 1800) -> (status: Int32, output: String)? {
        guard state == .enabled else { return nil }
        let connection = NSXPCConnection(machServiceName: HelperIdentity.machService, options: .privileged)
        // Talk only to the helper signed by the same team, never to something registered under its name.
        connection.setCodeSigningRequirement(HelperIdentity.helperRequirement)
        connection.remoteObjectInterface = NSXPCInterface(with: SwabrHelperProtocol.self)
        connection.resume()
        defer { connection.invalidate() }

        let result = Result()
        let done = DispatchSemaphore(value: 0)
        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in done.signal() } as? SwabrHelperProtocol
        guard let proxy else { return nil }
        proxy.run(script) { status, output in
            result.status = status
            result.output = output
            result.reached = true
            done.signal()
        }
        guard done.wait(timeout: .now() + timeout) == .success, result.reached else { return nil }
        return (result.status, result.output)
    }
}
