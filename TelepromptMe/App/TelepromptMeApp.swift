import SwiftUI
import SwiftData

@main
struct TelepromptMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup("Library") {
            LibraryView()
                .environment(appState)
        }
        .modelContainer(persistenceController.modelContainer)
        .defaultSize(width: 980, height: 640)
        .commands {
            TelepromptMeCommands(appState: appState)
        }

        Settings {
            SettingsWindowView()
                .environment(appState)
        }
        .modelContainer(persistenceController.modelContainer)
        .defaultSize(width: 1080, height: 760)
    }
}
