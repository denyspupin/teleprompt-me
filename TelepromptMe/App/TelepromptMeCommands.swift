import SwiftUI

struct TelepromptMeCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        CommandMenu("Playback") {
            shortcutMenuButton(
                title: appState.playbackController.state == .playing ? "Pause" : "Play",
                shortcut: appState.settingsSnapshot.togglePlaybackShortcut,
                isAssigned: appState.isTogglePlaybackShortcutAssigned
            ) {
                appState.togglePlayback()
            }

            shortcutMenuButton(
                title: "Stop",
                shortcut: appState.settingsSnapshot.stopPlaybackShortcut,
                isAssigned: appState.isStopPlaybackShortcutAssigned
            ) {
                appState.stop()
            }

            shortcutMenuButton(
                title: "Restart From Top",
                shortcut: appState.settingsSnapshot.restartPlaybackShortcut,
                isAssigned: appState.isRestartPlaybackShortcutAssigned
            ) {
                appState.restartPlayback()
            }

            Divider()

            shortcutMenuButton(
                title: "Show Overlay",
                shortcut: appState.settingsSnapshot.toggleOverlayShortcut,
                isAssigned: appState.isToggleOverlayShortcutAssigned
            ) {
                appState.presentOverlayIfNeeded()
            }

            shortcutMenuButton(
                title: "Faster",
                shortcut: appState.settingsSnapshot.increaseSpeedShortcut,
                isAssigned: appState.isIncreaseSpeedShortcutAssigned
            ) {
                appState.playbackController.increaseSpeed()
            }

            shortcutMenuButton(
                title: "Slower",
                shortcut: appState.settingsSnapshot.decreaseSpeedShortcut,
                isAssigned: appState.isDecreaseSpeedShortcutAssigned
            ) {
                appState.playbackController.decreaseSpeed()
            }

            shortcutMenuButton(
                title: "Step Forward",
                shortcut: appState.settingsSnapshot.stepForwardShortcut,
                isAssigned: appState.isStepForwardShortcutAssigned
            ) {
                appState.playbackController.stepForward()
            }

            shortcutMenuButton(
                title: "Step Backward",
                shortcut: appState.settingsSnapshot.stepBackwardShortcut,
                isAssigned: appState.isStepBackwardShortcutAssigned
            ) {
                appState.playbackController.stepBackward()
            }
        }
    }

    @ViewBuilder
    private func shortcutMenuButton(
        title: String,
        shortcut: AppShortcut,
        isAssigned: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if isAssigned {
            Button(title, action: action)
                .keyboardShortcut(
                    shortcut.key.keyEquivalent,
                    modifiers: shortcut.modifiers.eventModifiers
                )
        } else {
            Button(title, action: action)
        }
    }
}
