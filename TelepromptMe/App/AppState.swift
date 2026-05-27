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
    var settingsSnapshot = AppSettingsSnapshot.default
    var isToggleOverlayShortcutAssigned = true
    var isTogglePlaybackShortcutAssigned = true

    var isOverlayVisible = false
    var activeScriptID: String?
    var activeScriptTitle = "No Active Script"
    var activeScriptText = "Choose a script from the library to show it in the teleprompter overlay."
    var selectedDocumentID: String?
    var selectedCollectionID: String?
    var selectedSidebarItem: SidebarItem? = .allScripts

    init() {
        registerShortcuts()
    }

    func applySettings(_ settings: AppSettings) {
        let snapshot = settings.snapshot
        let shouldReregisterShortcuts =
            snapshot.toggleOverlayShortcut != settingsSnapshot.toggleOverlayShortcut ||
            snapshot.togglePlaybackShortcut != settingsSnapshot.togglePlaybackShortcut ||
            settings.isToggleOverlayShortcutAssigned != isToggleOverlayShortcutAssigned ||
            settings.isTogglePlaybackShortcutAssigned != isTogglePlaybackShortcutAssigned

        settingsSnapshot = snapshot
        isToggleOverlayShortcutAssigned = settings.isToggleOverlayShortcutAssigned
        isTogglePlaybackShortcutAssigned = settings.isTogglePlaybackShortcutAssigned
        playbackController.applySpeed(snapshot.playbackSpeedWordsPerMinute)

        if shouldReregisterShortcuts {
            registerShortcuts()
        }
    }

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

    func restartPlayback() {
        playbackController.restartFromTop()
        syncOverlayInteractivity()
    }

    func hideOverlay() {
        if playbackController.state == .playing {
            playbackController.pause()
        }
        overlayManager.hide()
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func presentOverlayIfNeeded() {
        overlayManager.present(appState: self)
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func toggleOverlay() {
        if isOverlayVisible {
            hideOverlay()
        } else {
            presentOverlayIfNeeded()
        }
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
        overlayManager.isInteractive = true
    }

    private func registerShortcuts() {
        shortcutManager.registerGlobalShortcuts(
            toggleOverlayShortcut: settingsSnapshot.toggleOverlayShortcut,
            togglePlaybackShortcut: settingsSnapshot.togglePlaybackShortcut,
            isToggleOverlayShortcutEnabled: isToggleOverlayShortcutAssigned,
            isTogglePlaybackShortcutEnabled: isTogglePlaybackShortcutAssigned,
            toggleOverlay: { [weak self] in
                self?.toggleOverlay()
            },
            togglePlayback: { [weak self] in
                self?.togglePlayback()
            },
            stopPlayback: { [weak self] in
                self?.stop()
            },
            restartPlayback: { [weak self] in
                self?.restartPlayback()
            },
            increaseSpeed: { [weak self] in
                self?.playbackController.increaseSpeed()
            },
            decreaseSpeed: { [weak self] in
                self?.playbackController.decreaseSpeed()
            }
        )
    }
}
