import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let modelContainer: ModelContainer
    let startupErrorMessage: String?

    private let schema = Schema([
        ScriptDocument.self,
        ScriptCollection.self,
        AppSettings.self,
    ])

    private init() {
        var resolvedContainer: ModelContainer?
        var startupError: String?

        do {
            let storeURL = try Self.makeStoreURL()
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            let container = try ModelContainer(for: schema, configurations: [configuration])
            try Self.seedDefaultsIfNeeded(using: container.mainContext)
            resolvedContainer = container
        } catch {
            startupError = error.localizedDescription
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let container = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfiguration]
                )
                try Self.seedDefaultsIfNeeded(using: container.mainContext)
                resolvedContainer = container
            } catch {
                preconditionFailure("Unable to initialize recovery persistence: \(error)")
            }
        }

        guard let resolvedContainer else {
            preconditionFailure("Persistence initialization completed without a model container.")
        }
        modelContainer = resolvedContainer
        startupErrorMessage = startupError
    }

    private static func seedDefaultsIfNeeded(using context: ModelContext) throws {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1

        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(AppSettings())
        try context.save()
    }

    func loadSettings() throws -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1

        if let settings = try modelContainer.mainContext.fetch(descriptor).first {
            return settings
        }

        let defaults = AppSettings()
        modelContainer.mainContext.insert(defaults)
        try modelContainer.mainContext.save()
        return defaults
    }

    private static func makeStoreURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("TelepromptMe", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path()) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL.appendingPathComponent("TelepromptMe.store")
    }
}
