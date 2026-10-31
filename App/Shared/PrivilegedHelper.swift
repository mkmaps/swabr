import Foundation
import ServiceManagement
import SwabrCore

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
        var data: Data?
    }

    /// Carries out root operations through the helper. Nil when the helper is not enabled, could not be reached
    /// or did not answer in time, so the caller can fall back to the password prompt.
    static func perform(_ operations: [RootOperation], timeout: TimeInterval = 1800) -> [RootResult]? {
        guard state == .enabled, let request = try? JSONEncoder().encode(RootRequest(operations)) else { return nil }
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
        proxy.perform(request) { data in
            result.data = data
            done.signal()
        }
        guard done.wait(timeout: .now() + timeout) == .success, let data = result.data,
              let results = try? JSONDecoder().decode([RootResult].self, from: data), results.count == operations.count
        else { return nil }
        return results
    }
}
