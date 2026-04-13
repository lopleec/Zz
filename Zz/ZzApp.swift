import SwiftUI

@main
struct ZzApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use Settings scene only
        Settings {
            SettingsView()
        }
    }
}
