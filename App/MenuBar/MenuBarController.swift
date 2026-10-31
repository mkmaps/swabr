import AppKit
import SwabrCore
import Observation
import SwiftUI

/// What the menu bar item shows next to its icon.
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case health, cpu, cpuMemory, icon
    var id: Self { self }

    var title: String {
        switch self {
        case .health: String(localized: "Gesundheitswert")
        case .cpu: "CPU"
        case .cpuMemory: String(localized: "CPU und RAM")
        case .icon: String(localized: "Nur Symbol")
        }
    }
}

enum MenuBarSettings {
    static let enabledKey = "menuBarEnabled"
    static let displayKey = "menuBarDisplay"
    static let hoverKey = "menuBarHover"

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var hover: Bool { UserDefaults.standard.object(forKey: hoverKey) as? Bool ?? true }
    static var display: MenuBarDisplay {
        MenuBarDisplay(rawValue: UserDefaults.standard.string(forKey: displayKey) ?? "") ?? .health
    }
}

/// Status item with a live value; hovering opens the mini dashboard, a click pins it open.
@MainActor
final class MenuBarController: NSResponder {
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private let model = StatusModel.shared
    /// Opened by a click: stays until the user clicks elsewhere.
    private var pinned = false
    private var hoverTimer: Timer?
    private var outsideSince: Date?
    private var animationTimer: Timer?
    private var animationFrame = Mascot.restFrame

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarDashboard(
            model: model,
            openApp: { [weak self] in self?.openMainWindow() },
            openSettings: { [weak self] in self?.openSettings() },
            openModule: { [weak self] module in
                self?.openMainWindow()
                Navigator.shared.open(module)
            }))
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(popoverClosed), name: NSPopover.didCloseNotification, object: popover)
        apply()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func settingsChanged() {
        Task { @MainActor in self.apply() }
    }

    private func apply() {
        if MenuBarSettings.enabled, item == nil {
            install()
        } else if !MenuBarSettings.enabled, let item {
            popover.close()
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
            model.release()
        }
        updateTitle()
    }

    private func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item = item
        guard let button = item.button else { return }
        button.image = Mascot.image(frame: Mascot.restFrame)
        button.image?.accessibilityDescription = Edition.appName
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(clicked)
        button.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
        model.acquire()
        observe()
        playAnimation()
    }

    /// Plays the mascot's short greeting animation once.
    private func playAnimation() {
        guard animationTimer == nil, let button = item?.button else { return }
        animationFrame = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1 / Mascot.fps, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                button.image = Mascot.image(frame: self.animationFrame)
                self.animationFrame += 1
                if self.animationFrame >= Mascot.frameCount {
                    self.animationTimer?.invalidate()
                    self.animationTimer = nil
                }
            }
        }
    }

    /// Re-renders the title whenever a new snapshot arrives.
    private func observe() {
        withObservationTracking {
            _ = model.snapshot
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.item != nil else { return }
                self.updateTitle()
                self.observe()
            }
        }
    }

    private func updateTitle() {
        guard let button = item?.button else { return }
        let text: String
        if let s = model.snapshot {
            switch MenuBarSettings.display {
            case .health: text = "\(s.health.score)"
            case .cpu: text = String(format: "%.0f %%", s.cpu.usage)
            case .cpuMemory: text = String(format: "%.0f %% · %.0f %%", s.cpu.usage, s.memory.usedPercent)
            case .icon: text = ""
            }
        } else {
            text = MenuBarSettings.display == .icon ? "" : "…"
        }
        button.attributedTitle = NSAttributedString(
            string: text.isEmpty ? "" : " " + text,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .medium)])
        button.toolTip = model.snapshot.map { String(localized: "Swabr · Zustand \($0.health.score) (\($0.health.label))") } ?? "Swabr"
    }

    // MARK: Opening and closing

    @objc private func clicked() {
        if popover.isShown, pinned {
            popover.performClose(nil)
        } else {
            pinned = true
            stopHoverWatch()
            show()
            NSApp.activate()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard MenuBarSettings.hover, !popover.isShown else { return }
        pinned = false
        show()
        startHoverWatch()
    }

    private func show() {
        guard let button = item?.button, !popover.isShown else { return }
        playAnimation()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// While opened by hovering, close once the pointer has left both the icon and the popover for a moment.
    private func startHoverWatch() {
        stopHoverWatch()
        outsideSince = nil
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkHover() }
        }
    }

    private func checkHover() {
        guard popover.isShown, !pinned else { return stopHoverWatch() }
        let mouse = NSEvent.mouseLocation
        let frames = [item?.button?.window?.frame, popover.contentViewController?.view.window?.frame].compactMap { $0 }
        if frames.contains(where: { $0.insetBy(dx: -6, dy: -6).contains(mouse) }) {
            outsideSince = nil
        } else if let since = outsideSince {
            if Date().timeIntervalSince(since) > 0.4 { popover.performClose(nil) }
        } else {
            outsideSince = Date()
        }
    }

    private func stopHoverWatch() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    @objc private func popoverClosed() {
        Task { @MainActor in
            self.pinned = false
            self.stopHoverWatch()
        }
    }

    private func openMainWindow() {
        popover.performClose(nil)
        NSApp.activate()
        WindowOpener.shared.openMain()
    }

    private func openSettings() {
        popover.performClose(nil)
        WindowOpener.shared.openSettings()
    }
}
