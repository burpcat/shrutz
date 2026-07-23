import AppKit
import SwiftUI
import Combine

/// Hosts the redesigned dropdown card in a borderless, non-activating
/// NSPanel — not NSPopover, which draws its own AppKit chrome that would
/// fight the custom frosted-glass card (rounded rect + .ultraThinMaterial
/// + animated color blobs, all supplied by SwiftUI). Being non-opaque and
/// clear lets .ultraThinMaterial genuinely sample the real desktop behind
/// the floating panel.
final class PanelWindowController: NSWindowController {
    private var globalClickMonitor: Any?
    private var hostingView: NSHostingView<AnyView>?
    private weak var appState: AppState?
    private var expandedCancellable: AnyCancellable?
    private var lastButton: NSStatusBarButton?

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
        self.appState = appState

        expandedCancellable = appState.$panelIsExpanded
            .dropFirst()
            .sink { [weak self] _ in
                self?.resize(animated: true)
            }
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
        guard let panel = window else { return }
        lastButton = button
        // The popover always opens collapsed — "shown slick, after a click."
        appState?.panelIsExpanded = false

        resize(animated: false)
        panel.orderFrontRegardless()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    /// Resizes/repositions the panel to fit its current SwiftUI content,
    /// keeping the top edge anchored just below the status item button so
    /// expanding grows the panel downward rather than from its center.
    private func resize(animated: Bool) {
        guard let panel = window, let hosting = hostingView, let buttonWindow = lastButton?.window else { return }

        let fittingSize = hosting.fittingSize
        let buttonFrame = buttonWindow.frame
        let newFrame = NSRect(
            x: buttonFrame.midX - fittingSize.width / 2,
            y: buttonFrame.minY - fittingSize.height - 4,
            width: fittingSize.width,
            height: fittingSize.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    // A `.nonactivatingPanel` can never become key — makeKeyAndOrderFront
    // silently no-ops on the "key" half and, empirically, can leave the
    // panel ordered beneath the currently active app instead of above it.
    // orderFrontRegardless() (used above) doesn't require key status and
    // reliably brings it to the front regardless of which app is active.

    override func close() {
        window?.orderOut(nil)
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
