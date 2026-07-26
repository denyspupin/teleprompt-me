import SwiftUI

private struct NewScriptActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newScriptAction: (() -> Void)? {
        get { self[NewScriptActionKey.self] }
        set { self[NewScriptActionKey.self] = newValue }
    }
}

struct TelepromptMeCommands: Commands {
    @Bindable var appState: AppState
    @FocusedValue(\.newScriptAction) private var newScriptAction

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Script") {
                newScriptAction?()
            }
            .keyboardShortcut("n")
            .disabled(newScriptAction == nil)
        }

        CommandMenu("Playback") {
            shortcutMenuButton(
                title: appState.playbackController.state == .playing ? "Pause" : "Play",
                shortcut: appState.settingsSnapshot.togglePlaybackShortcut,
                isAssigned: appState.isTogglePlaybackShortcutAssigned
            ) {
                appState.togglePlayback()
            }

            Button("Stop") {
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
                title: appState.isOverlayVisible ? "Hide Overlay" : "Show Overlay",
                shortcut: appState.settingsSnapshot.toggleOverlayShortcut,
                isAssigned: appState.isToggleOverlayShortcutAssigned
            ) {
                appState.toggleOverlay()
            }

            Divider()

            Button("Faster") {
                appState.playbackController.increaseSpeed()
            }

            Button("Slower") {
                appState.playbackController.decreaseSpeed()
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
