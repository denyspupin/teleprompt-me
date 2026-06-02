import Observation
import Foundation

@MainActor
@Observable
final class AppState {
    enum SidebarItem: Hashable {
        case allScripts
        case favorites
        case collection(String)
        case settings
    }

    let overlayManager = OverlayWindowManager()
    let playbackController = PlaybackController()
    let shortcutManager = ShortcutManager()
    var settingsSnapshot = AppSettingsSnapshot.default
    var isToggleOverlayShortcutAssigned = true
    var isTogglePlaybackShortcutAssigned = true
    var isHoldToScrollShortcutAssigned = true
    var isStopPlaybackShortcutAssigned = true
    var isRestartPlaybackShortcutAssigned = true
    var isIncreaseSpeedShortcutAssigned = true
    var isDecreaseSpeedShortcutAssigned = true
    var isStepForwardShortcutAssigned = true
    var isStepBackwardShortcutAssigned = true

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
            snapshot.holdToScrollShortcut != settingsSnapshot.holdToScrollShortcut ||
            snapshot.stopPlaybackShortcut != settingsSnapshot.stopPlaybackShortcut ||
            snapshot.restartPlaybackShortcut != settingsSnapshot.restartPlaybackShortcut ||
            snapshot.increaseSpeedShortcut != settingsSnapshot.increaseSpeedShortcut ||
            snapshot.decreaseSpeedShortcut != settingsSnapshot.decreaseSpeedShortcut ||
            snapshot.stepForwardShortcut != settingsSnapshot.stepForwardShortcut ||
            snapshot.stepBackwardShortcut != settingsSnapshot.stepBackwardShortcut ||
            settings.isToggleOverlayShortcutAssigned != isToggleOverlayShortcutAssigned ||
            settings.isTogglePlaybackShortcutAssigned != isTogglePlaybackShortcutAssigned ||
            settings.isHoldToScrollShortcutAssigned != isHoldToScrollShortcutAssigned ||
            settings.isStopPlaybackShortcutAssigned != isStopPlaybackShortcutAssigned ||
            settings.isRestartPlaybackShortcutAssigned != isRestartPlaybackShortcutAssigned ||
            settings.isIncreaseSpeedShortcutAssigned != isIncreaseSpeedShortcutAssigned ||
            settings.isDecreaseSpeedShortcutAssigned != isDecreaseSpeedShortcutAssigned ||
            settings.isStepForwardShortcutAssigned != isStepForwardShortcutAssigned ||
            settings.isStepBackwardShortcutAssigned != isStepBackwardShortcutAssigned

        settingsSnapshot = snapshot
        isToggleOverlayShortcutAssigned = settings.isToggleOverlayShortcutAssigned
        isTogglePlaybackShortcutAssigned = settings.isTogglePlaybackShortcutAssigned
        isHoldToScrollShortcutAssigned = settings.isHoldToScrollShortcutAssigned
        isStopPlaybackShortcutAssigned = settings.isStopPlaybackShortcutAssigned
        isRestartPlaybackShortcutAssigned = settings.isRestartPlaybackShortcutAssigned
        isIncreaseSpeedShortcutAssigned = settings.isIncreaseSpeedShortcutAssigned
        isDecreaseSpeedShortcutAssigned = settings.isDecreaseSpeedShortcutAssigned
        isStepForwardShortcutAssigned = settings.isStepForwardShortcutAssigned
        isStepBackwardShortcutAssigned = settings.isStepBackwardShortcutAssigned
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

    func beginHoldToScroll() {
        guard isOverlayVisible else { return }
        playbackController.beginHoldScroll()
    }

    func endHoldToScroll() {
        playbackController.endHoldScroll()
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
            holdToScrollShortcut: settingsSnapshot.holdToScrollShortcut,
            stopPlaybackShortcut: settingsSnapshot.stopPlaybackShortcut,
            restartPlaybackShortcut: settingsSnapshot.restartPlaybackShortcut,
            increaseSpeedShortcut: settingsSnapshot.increaseSpeedShortcut,
            decreaseSpeedShortcut: settingsSnapshot.decreaseSpeedShortcut,
            stepForwardShortcut: settingsSnapshot.stepForwardShortcut,
            stepBackwardShortcut: settingsSnapshot.stepBackwardShortcut,
            isToggleOverlayShortcutEnabled: isToggleOverlayShortcutAssigned,
            isTogglePlaybackShortcutEnabled: isTogglePlaybackShortcutAssigned,
            isHoldToScrollShortcutEnabled: isHoldToScrollShortcutAssigned,
            isStopPlaybackShortcutEnabled: isStopPlaybackShortcutAssigned,
            isRestartPlaybackShortcutEnabled: isRestartPlaybackShortcutAssigned,
            isIncreaseSpeedShortcutEnabled: isIncreaseSpeedShortcutAssigned,
            isDecreaseSpeedShortcutEnabled: isDecreaseSpeedShortcutAssigned,
            isStepForwardShortcutEnabled: isStepForwardShortcutAssigned,
            isStepBackwardShortcutEnabled: isStepBackwardShortcutAssigned,
            toggleOverlay: { [weak self] in
                self?.toggleOverlay()
            },
            togglePlayback: { [weak self] in
                self?.togglePlayback()
            },
            beginHoldToScroll: { [weak self] in
                self?.beginHoldToScroll()
            },
            endHoldToScroll: { [weak self] in
                self?.endHoldToScroll()
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
            },
            stepForward: { [weak self] in
                self?.playbackController.stepForward()
            },
            stepBackward: { [weak self] in
                self?.playbackController.stepBackward()
            }
        )
    }
}
