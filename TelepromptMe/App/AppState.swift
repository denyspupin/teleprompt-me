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
        overlayManager.present()
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func toggleOverlay() {
        overlayManager.toggle()
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func syncOverlayInteractivity() {
        overlayManager.isInteractive = playbackController.state != .playing
    }
}
