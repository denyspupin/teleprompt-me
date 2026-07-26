import Observation
import Foundation

@MainActor
@Observable
final class AppState {
    enum SidebarItem: Hashable {
        case allScripts
        case favorites
        case collection(String)
    }

    let overlayManager = OverlayWindowManager()
    let playbackController = PlaybackController()
    let speechFollowController = SpeechFollowController()
    let shortcutManager = ShortcutManager()
    var settingsSnapshot = AppSettingsSnapshot.default
    var isToggleOverlayShortcutAssigned = true
    var isTogglePlaybackShortcutAssigned = true
    var isRestartPlaybackShortcutAssigned = true

    var isOverlayVisible = false
    var activeScriptID: String?
    var activeScriptTitle = "No Active Script"
    var activeScriptText = "Choose a script from the library to show it in the teleprompter overlay."
    var selectedDocumentID: String?
    var selectedCollectionID: String?
    var selectedSidebarItem: SidebarItem? = .allScripts
    var persistenceWarningMessage: String?

    init() {
        registerShortcuts()
    }

    func applySettings(_ settings: AppSettings) {
        let snapshot = settings.snapshot
        let shouldReregisterShortcuts =
            snapshot.toggleOverlayShortcut != settingsSnapshot.toggleOverlayShortcut ||
            snapshot.togglePlaybackShortcut != settingsSnapshot.togglePlaybackShortcut ||
            snapshot.restartPlaybackShortcut != settingsSnapshot.restartPlaybackShortcut ||
            settings.isToggleOverlayShortcutAssigned != isToggleOverlayShortcutAssigned ||
            settings.isTogglePlaybackShortcutAssigned != isTogglePlaybackShortcutAssigned ||
            settings.isRestartPlaybackShortcutAssigned != isRestartPlaybackShortcutAssigned

        settingsSnapshot = snapshot
        isToggleOverlayShortcutAssigned = settings.isToggleOverlayShortcutAssigned
        isTogglePlaybackShortcutAssigned = settings.isTogglePlaybackShortcutAssigned
        isRestartPlaybackShortcutAssigned = settings.isRestartPlaybackShortcutAssigned
        playbackController.applySpeed(snapshot.playbackSpeedWordsPerMinute)

        if shouldReregisterShortcuts {
            registerShortcuts()
        }
    }

    func togglePlayback() {
        if speechFollowController.isListening {
            stopVoiceFollow()
        }
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
        stopVoiceFollow()
        playbackController.stop()
        syncOverlayInteractivity()
    }

    func restartPlayback() {
        stopVoiceFollow()
        playbackController.restartFromTop()
        syncOverlayInteractivity()
    }

    func hideOverlay() {
        if playbackController.state == .playing {
            playbackController.pause()
        }
        stopVoiceFollow()
        overlayManager.hide()
        isOverlayVisible = overlayManager.isVisible
        syncOverlayInteractivity()
    }

    func presentOverlayIfNeeded() {
        overlayManager.present(appState: self)
        isOverlayVisible = overlayManager.isVisible
        if settingsSnapshot.isVoiceFollowEnabledByDefault {
            startVoiceFollow()
        }
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
        stopVoiceFollow()
        activeScriptID = id
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        activeScriptTitle = trimmedTitle.isEmpty ? "Untitled Script" : trimmedTitle
        activeScriptText = trimmedText.isEmpty ? "This script is empty."
            : trimmedText
    }

    func toggleVoiceFollow() {
        if speechFollowController.isListening {
            stopVoiceFollow()
        } else {
            startVoiceFollow()
        }
    }

    func startVoiceFollow() {
        playbackController.pause()
        speechFollowController.start(
            script: activeScriptText,
            localeIdentifier: settingsSnapshot.selectedSpeechLocaleIdentifier,
            sensitivity: settingsSnapshot.speechFollowSensitivity,
            playbackController: playbackController
        )
    }

    func stopVoiceFollow() {
        speechFollowController.stop()
    }

    func syncOverlayInteractivity() {
        overlayManager.isInteractive = true
    }

    private func registerShortcuts() {
        shortcutManager.registerGlobalShortcuts(
            toggleOverlayShortcut: settingsSnapshot.toggleOverlayShortcut,
            togglePlaybackShortcut: settingsSnapshot.togglePlaybackShortcut,
            restartPlaybackShortcut: settingsSnapshot.restartPlaybackShortcut,
            isToggleOverlayShortcutEnabled: isToggleOverlayShortcutAssigned,
            isTogglePlaybackShortcutEnabled: isTogglePlaybackShortcutAssigned,
            isRestartPlaybackShortcutEnabled: isRestartPlaybackShortcutAssigned,
            toggleOverlay: { [weak self] in
                self?.toggleOverlay()
            },
            togglePlayback: { [weak self] in
                self?.togglePlayback()
            },
            restartPlayback: { [weak self] in
                self?.restartPlayback()
            }
        )
    }
}
