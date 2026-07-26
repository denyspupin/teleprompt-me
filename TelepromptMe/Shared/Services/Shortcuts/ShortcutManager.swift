import Carbon

@MainActor
final class ShortcutManager {
    private enum ShortcutID: UInt32 {
        case toggleOverlay = 1
        case togglePlayback = 2
        case restartPlayback = 3
    }

    private static let hotKeySignature: OSType = 0x54504D45 // TPME
    private static var sharedHandler: EventHandlerRef?
    private static var sharedManagers: [ObjectIdentifier: ShortcutManager] = [:]

    private var hotKeyRefs: [ShortcutID: EventHotKeyRef] = [:]
    private var actions: [ShortcutID: () -> Void] = [:]

    func registerGlobalShortcuts(
        toggleOverlayShortcut: AppShortcut,
        togglePlaybackShortcut: AppShortcut,
        restartPlaybackShortcut: AppShortcut,
        isToggleOverlayShortcutEnabled: Bool,
        isTogglePlaybackShortcutEnabled: Bool,
        isRestartPlaybackShortcutEnabled: Bool,
        toggleOverlay: @escaping () -> Void,
        togglePlayback: @escaping () -> Void,
        restartPlayback: @escaping () -> Void
    ) {
        unregisterGlobalShortcuts()
        installHandlerIfNeeded()

        actions = [
            .toggleOverlay: toggleOverlay,
            .togglePlayback: togglePlayback,
            .restartPlayback: restartPlayback,
        ]
        Self.sharedManagers[ObjectIdentifier(self)] = self

        if isToggleOverlayShortcutEnabled {
            registerHotKey(.toggleOverlay, shortcut: toggleOverlayShortcut)
        }
        if isTogglePlaybackShortcutEnabled {
            registerHotKey(.togglePlayback, shortcut: togglePlaybackShortcut)
        }
        if isRestartPlaybackShortcutEnabled {
            registerHotKey(.restartPlayback, shortcut: restartPlaybackShortcut)
        }
    }

    func unregisterGlobalShortcuts() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        actions.removeAll()
        Self.sharedManagers.removeValue(forKey: ObjectIdentifier(self))
    }

    deinit {
        let refs = hotKeyRefs.values
        let identifier = ObjectIdentifier(self)
        Task { @MainActor in
            for ref in refs {
                UnregisterEventHotKey(ref)
            }
            Self.sharedManagers.removeValue(forKey: identifier)
        }
    }

    private func registerHotKey(_ id: ShortcutID, shortcut: AppShortcut) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: id.rawValue)

        RegisterEventHotKey(
            shortcut.key.carbonKeyCode,
            shortcut.modifiers.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if let hotKeyRef {
            hotKeyRefs[id] = hotKeyRef
        }
    }

    private func handle(shortcutID: UInt32) {
        guard let id = ShortcutID(rawValue: shortcutID) else { return }
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard Self.sharedHandler == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr, hotKeyID.signature == ShortcutManager.hotKeySignature else {
                    return noErr
                }

                Task { @MainActor in
                    for manager in ShortcutManager.sharedManagers.values {
                        manager.handle(shortcutID: hotKeyID.id)
                    }
                }
                return noErr
            },
            1,
            &eventSpec,
            nil,
            &Self.sharedHandler
        )
    }
}
