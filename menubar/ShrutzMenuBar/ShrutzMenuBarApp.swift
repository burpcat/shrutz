import SwiftUI

@main
struct ShrutzMenuBarApp: App {
    @StateObject private var appState: AppState
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        // @NSApplicationDelegateAdaptor creates the AppDelegate instance
        // eagerly, before this initializer runs — safe to hand it appState
        // right now, before AppKit calls applicationDidFinishLaunching.
        AppDelegateBridge.pendingAppState = state
    }

    var body: some Scene {
        // Inert: LSUIElement apps have no app menu, so nothing ever shows
        // this scene's window. Real UI is entirely AppDelegate-owned (see
        // App/AppDelegate.swift) — this only exists to satisfy `some Scene`.
        Settings {
            EmptyView()
        }
    }
}

/// Small hand-off point so `AppDelegate.appState` is assigned before
/// `applicationDidFinishLaunching` fires, without `ShrutzMenuBarApp.init()`
/// needing direct access to the `@NSApplicationDelegateAdaptor`-owned
/// instance (property wrapper initialization order makes that awkward).
enum AppDelegateBridge {
    static var pendingAppState: AppState?
}
