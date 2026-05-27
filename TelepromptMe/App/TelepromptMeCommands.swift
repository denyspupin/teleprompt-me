import SwiftUI

struct TelepromptMeCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        CommandMenu("Playback") {
            if appState.isTogglePlaybackShortcutAssigned {
                Button(appState.playbackController.state == .playing ? "Pause" : "Play") {
                    appState.togglePlayback()
                }
                .keyboardShortcut(
                    appState.settingsSnapshot.togglePlaybackShortcut.key.keyEquivalent,
                    modifiers: appState.settingsSnapshot.togglePlaybackShortcut.modifiers.eventModifiers
                )
            } else {
                Button(appState.playbackController.state == .playing ? "Pause" : "Play") {
                    appState.togglePlayback()
                }
            }

            Button("Stop") {
                appState.stop()
            }
            .keyboardShortcut(".", modifiers: [.command])

            Button("Restart From Top") {
                appState.restartPlayback()
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])

            Divider()

            if appState.isToggleOverlayShortcutAssigned {
                Button("Show Overlay") {
                    appState.presentOverlayIfNeeded()
                }
                .keyboardShortcut(
                    appState.settingsSnapshot.toggleOverlayShortcut.key.keyEquivalent,
                    modifiers: appState.settingsSnapshot.toggleOverlayShortcut.modifiers.eventModifiers
                )
            } else {
                Button("Show Overlay") {
                    appState.presentOverlayIfNeeded()
                }
            }

            Button("Faster") {
                appState.playbackController.increaseSpeed()
            }
            .keyboardShortcut("=", modifiers: [.command, .shift])

            Button("Slower") {
                appState.playbackController.decreaseSpeed()
            }
            .keyboardShortcut("-", modifiers: [.command, .shift])

            Button("Step Forward") {
                appState.playbackController.stepForward()
            }
            .keyboardShortcut(.downArrow, modifiers: [.option])

            Button("Step Backward") {
                appState.playbackController.stepBackward()
            }
            .keyboardShortcut(.upArrow, modifiers: [.option])
        }
    }
}
