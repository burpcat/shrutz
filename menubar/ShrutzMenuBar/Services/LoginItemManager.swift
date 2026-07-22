import ServiceManagement

/// Wraps SMAppService (macOS 13+) for "Launch at Login" — this API can
/// only be called by the running app itself, never triggered from bash,
/// which is why this lives here rather than as a shrutz CLI command.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LoginItemManager: failed to \(enabled ? "register" : "unregister") — \(error)")
        }
    }
}
