import SwiftUI

@main
struct OffloadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView(
                appState: appState,
                onPreferences: { appDelegate.openSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        } label: {
            if appState.importProgress > 0 && appState.importProgress < 1.0 {
                Text("\(Int(appState.importProgress * 100))%")
                    .monospacedDigit()
            } else {
                Image(systemName: "sdcard.fill")
            }
        }

    }
}
