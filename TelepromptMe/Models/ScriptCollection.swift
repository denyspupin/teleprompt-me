import Foundation
import SwiftData

@Model
final class ScriptCollection {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ScriptDocument.collection) var documents: [ScriptDocument]

    init(id: String = UUID().uuidString, name: String, createdAt: Date = .now, documents: [ScriptDocument] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.documents = documents
    }
}
