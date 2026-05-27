import Observation

@MainActor
@Observable
final class AppState {
    let overlayManager = OverlayWindowManager()
    let playbackController = PlaybackController()
    let shortcutManager = ShortcutManager()

    var selectedDocumentID: String?
    var selectedCollectionID: String?

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
        syncOverlayInteractivity()
    }

    func syncOverlayInteractivity() {
        overlayManager.isInteractive = playbackController.state != .playing
    }
}
