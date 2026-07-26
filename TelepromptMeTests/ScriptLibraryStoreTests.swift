import SwiftData
import XCTest
@testable import TelepromptMe

@MainActor
final class ScriptLibraryStoreTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            ScriptDocument.self,
            ScriptCollection.self,
            AppSettings.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testScriptPersistsAfterSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = ScriptLibraryStore(context: context)
        context.insert(ScriptDocument(title: "Launch", plainText: "Hello"))

        try store.save()

        let scripts = try context.fetch(FetchDescriptor<ScriptDocument>())
        XCTAssertEqual(scripts.count, 1)
        XCTAssertEqual(scripts.first?.title, "Launch")
        XCTAssertEqual(scripts.first?.plainText, "Hello")
    }

    func testDeletingCollectionPreservesItsScripts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = ScriptLibraryStore(context: context)
        let collection = ScriptCollection(name: "Keynotes")
        let script = ScriptDocument(title: "Launch", plainText: "Hello", collection: collection)
        context.insert(collection)
        context.insert(script)
        try store.save()

        try store.deleteCollectionPreservingScripts(collection)

        XCTAssertTrue(try context.fetch(FetchDescriptor<ScriptCollection>()).isEmpty)
        let scripts = try context.fetch(FetchDescriptor<ScriptDocument>())
        XCTAssertEqual(scripts.count, 1)
        XCTAssertNil(scripts.first?.collection)
    }

    func testDeletingScriptRemovesIt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = ScriptLibraryStore(context: context)
        let script = ScriptDocument(title: "Draft", plainText: "")
        context.insert(script)
        try store.save()

        try store.delete(script)

        XCTAssertTrue(try context.fetch(FetchDescriptor<ScriptDocument>()).isEmpty)
    }
}
