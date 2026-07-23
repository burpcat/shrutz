import AppKit
import SwiftUI

/// Hosts the redesigned dropdown card in a borderless, non-activating
/// NSPanel — not NSPopover, which draws its own AppKit chrome that would
/// fight the custom frosted-glass card (rounded rect + .ultraThinMaterial
/// + animated color blobs, all supplied by SwiftUI). Being non-opaque and
/// clear lets .ultraThinMaterial genuinely sample the real desktop behind
/// the floating panel.
final class PanelWindowController: NSWindowController {
    private var globalClickMonitor: Any?
    private var hostingView: NSHostingView<AnyView>?

    convenience init(appState: AppState, onSettingsTapped: @escaping () -> Void) {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let rootView = AnyView(
            ShrutzPanelView(onSettingsTapped: onSettingsTapped)
                .environmentObject(appState)
        )
        let hosting = NSHostingView(rootView: rootView)
        panel.contentView = hosting

        self.init(window: panel)
        self.hostingView = hosting
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        guard let panel = window else { return }
        if panel.isVisible {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    private func show(relativeTo button: NSStatusBarButton) {
        guard let panel = window, let buttonWindow = button.window, let hosting = hostingView else { return }

        let fittingSize = hosting.fittingSize
        panel.setContentSize(fittingSize)

        let buttonFrame = buttonWindow.frame
        let origin = NSPoint(
            x: buttonFrame.midX - fittingSize.width / 2,
            y: buttonFrame.minY - fittingSize.height - 4
        )
        panel.setFrameOrigin(origin)
        // A `.nonactivatingPanel` can never become key — makeKeyAndOrderFront
        // silently no-ops on the "key" half and, empirically, can leave the
        // panel ordered beneath the currently active app instead of above
        // it. orderFrontRegardless() doesn't require key status and
        // reliably brings it to the front regardless of which app is active.
        panel.orderFrontRegardless()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    override func close() {
        window?.orderOut(nil)
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
