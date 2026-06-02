import Foundation

extension String {
    var wordCount: Int {
        split(whereSeparator: \.isWhitespace).count
    }
}

extension Date {
    var relativeLibraryDate: String {
        formatted(.relative(presentation: .named))
    }
}
