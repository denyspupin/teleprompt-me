import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let modelContainer: ModelContainer

    private let schema = Schema([
        ScriptDocument.self,
        ScriptCollection.self,
        AppSettings.self,
    ])

    private init() {
        do {
            let storeURL = try Self.makeStoreURL()
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            try seedDefaultsIfNeeded(using: modelContainer.mainContext)
        } catch {
            fatalError("Unable to initialize local persistence: \(error)")
        }
    }

    private func seedDefaultsIfNeeded(using context: ModelContext) throws {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1

        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(AppSettings())
        try context.save()
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
