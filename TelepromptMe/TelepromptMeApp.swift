import SwiftUI
import SwiftData

@main
struct TelepromptMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ScriptDocument.self,
            ScriptCollection.self,
            AppSettings.self,
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup("Library") {
            LibraryView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 980, height: 640)
        .commands {
            TelepromptMeCommands(appState: appState)
        }

        Settings {
            SettingsWindowView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1080, height: 760)
    }
}
