import SwiftUI
import SwiftData

@main
struct TelepromptMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    private let persistenceController = PersistenceController.shared

    init() {
        let state = AppState()
        state.persistenceWarningMessage = persistenceController.startupErrorMessage
        if let settings = try? persistenceController.loadSettings() {
            state.applySettings(settings)
        }
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup("") {
            LibraryView()
                .environment(appState)
        }
        .modelContainer(persistenceController.modelContainer)
        .defaultSize(width: 980, height: 640)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            TelepromptMeCommands(appState: appState)
        }

        Settings {
            SettingsWindowView()
                .environment(appState)
        }
        .modelContainer(persistenceController.modelContainer)
        .defaultSize(width: 620, height: 520)
    }
}
