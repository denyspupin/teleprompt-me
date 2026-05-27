import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var fontName: String
    var fontSize: Double
    var lineSpacing: Double
    var overlayOpacity: Double
    var showDockIcon: Bool
    var showMenuBarItem: Bool
    var keepOverlayCentered: Bool

    init(
        id: String = "default-settings",
        fontName: String = "SF Pro",
        fontSize: Double = 42,
        lineSpacing: Double = 12,
        overlayOpacity: Double = 0.92,
        showDockIcon: Bool = true,
        showMenuBarItem: Bool = true,
        keepOverlayCentered: Bool = true
    ) {
        self.id = id
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.overlayOpacity = overlayOpacity
        self.showDockIcon = showDockIcon
        self.showMenuBarItem = showMenuBarItem
        self.keepOverlayCentered = keepOverlayCentered
    }
}
