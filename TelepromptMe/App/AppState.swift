import Observation
import Foundation

@MainActor
@Observable
final class AppState {
    enum SidebarItem: Hashable {
        case allScripts
        case favorites
        case tags
        case collection(String)
        case settings
    }

    let overlayManager = OverlayWindowManager()
    let playbackController = PlaybackController()
    let shortcutManager = ShortcutManager()

    var isOverlayVisible = false
    var activeScriptID: String?
    var activeScriptTitle = "No Active Script"
    var activeScriptText = "Choose a script from the library to show it in the teleprompter overlay."
    var selectedDocumentID: String?
    var selectedCollectionID: String?
    var selectedSidebarItem: SidebarItem? = .allScripts

    func togglePlayback() {
        playbackController.togglePlayback()
        syncOverlayInteractivity()
    }

    func play() {
        playbackController.play()
        syncOverlayInteractivity()
    }

    func pause() {
        playbackController.pause()
        syncOverlayInteractivity()
    }

    func stop() {
        playbackController.stop()
        syncOverlayInteractivity()
    }

    func presentOverlayIfNeeded() {
        overlayManager.present(appState: self)
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func toggleOverlay() {
        overlayManager.toggle(appState: self)
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func activateScript(id: String? = nil, title: String, text: String) {
        activeScriptID = id
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        activeScriptTitle = trimmedTitle.isEmpty ? "Untitled Script" : trimmedTitle
        activeScriptText = trimmedText.isEmpty ? "This script is empty."
            : trimmedText
    }

    func syncOverlayInteractivity() {
        overlayManager.isInteractive = playbackController.state != .playing
    }
}
