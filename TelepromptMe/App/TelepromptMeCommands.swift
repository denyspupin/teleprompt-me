import SwiftUI

struct TelepromptMeCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        CommandMenu("Playback") {
            Button(appState.playbackController.state == .playing ? "Pause" : "Play") {
                appState.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Stop") {
                appState.stop()
            }
            .keyboardShortcut(".", modifiers: [.command])

            Divider()

            Button("Show Overlay") {
                appState.presentOverlayIfNeeded()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

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
