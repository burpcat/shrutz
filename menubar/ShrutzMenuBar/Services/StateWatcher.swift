import Foundation
import AppKit

/// Watches shrutz's state file for writes and fires a callback — the
/// daemon rewrites it via a truncating `>` redirect on every tick
/// (~every CHECK_EVERY seconds while running, and immediately on every
/// switch/pause/resume/next/prev), so a single fd opened once at launch
/// stays valid and this alone gives near-instant UI updates for anything
/// the daemon itself does.
///
/// Daemon *liveness* is a separate, launchd-level fact this watch can't
/// see (stopping the daemon just means writes stop) — a slow poll fills
/// that gap.
final class StateWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pollTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    var onChange: (() -> Void)?

    private var statePath: String {
        NSHomeDirectory() + "/.local/lib/shrutz/state"
    }

    func start() {
        watchStateFile()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.onChange?()
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.onChange?()
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func watchStateFile() {
        let fd = open(statePath, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.onChange?()
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }
        src.resume()
        source = src
    }

    deinit {
        stop()
    }
}
