import SwiftData

@MainActor
final class ScriptLibraryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save() throws {
        try context.save()
    }

    func delete(_ document: ScriptDocument) throws {
        context.delete(document)
        try context.save()
    }

    func deleteCollectionPreservingScripts(_ collection: ScriptCollection) throws {
        for document in collection.documents {
            document.collection = nil
        }
        context.delete(collection)
        try context.save()
    }
}
