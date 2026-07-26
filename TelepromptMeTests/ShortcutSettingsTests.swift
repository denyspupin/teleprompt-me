import SwiftData
import XCTest
@testable import TelepromptMe

@MainActor
final class ShortcutSettingsTests: XCTestCase {
    func testVersionOneDefaultShortcutsAreDistinctAndAssigned() {
        let settings = AppSettings()

        XCTAssertTrue(settings.isToggleOverlayShortcutAssigned)
        XCTAssertTrue(settings.isTogglePlaybackShortcutAssigned)
        XCTAssertTrue(settings.isRestartPlaybackShortcutAssigned)

        let shortcuts = [
            settings.toggleOverlayShortcut,
            settings.togglePlaybackShortcut,
            settings.restartPlaybackShortcut,
        ]
        XCTAssertEqual(Set(shortcuts.map(\.displayName)).count, shortcuts.count)
    }

    func testShortcutCanBeCustomizedAndCleared() {
        let settings = AppSettings()
        let customShortcut = AppShortcut(key: .t, modifiers: [.command, .option])

        settings.toggleOverlayShortcut = customShortcut
        XCTAssertEqual(settings.toggleOverlayShortcut, customShortcut)

        settings.toggleOverlayShortcutModifiersRawValue = -1
        XCTAssertFalse(settings.isToggleOverlayShortcutAssigned)
    }

    func testCustomizedShortcutPersists() throws {
        let schema = Schema([
            ScriptDocument.self,
            ScriptCollection.self,
            AppSettings.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let settings = AppSettings()
        settings.togglePlaybackShortcut = AppShortcut(key: .space, modifiers: [.control])
        context.insert(settings)

        try context.save()

        let storedSettings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettings>()).first)
        XCTAssertEqual(
            storedSettings.togglePlaybackShortcut,
            AppShortcut(key: .space, modifiers: [.control])
        )
    }
}
