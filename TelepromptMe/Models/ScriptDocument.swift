import Foundation
import SwiftData

@Model
final class ScriptDocument {
    @Attribute(.unique) var id: String
    var title: String
    var plainText: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var tagNames: [String]
    var collection: ScriptCollection?

    init(
        id: String = UUID().uuidString,
        title: String,
        plainText: String,
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        tagNames: [String] = [],
        collection: ScriptCollection? = nil
    ) {
        self.id = id
        self.title = title
        self.plainText = plainText
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tagNames = tagNames
        self.collection = collection
    }
}
