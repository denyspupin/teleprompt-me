import AppKit
import Carbon

@MainActor
final class ShortcutManager {
    private enum ShortcutID: UInt32 {
        case toggleOverlay = 1
        case togglePlayback = 2
        case stopPlayback = 3
        case restartPlayback = 4
        case increaseSpeed = 5
        case decreaseSpeed = 6
    }

    private static let hotKeySignature: OSType = 0x54504D45 // TPME
    private static var sharedHandler: EventHandlerRef?
    private static var sharedManagers: [ObjectIdentifier: ShortcutManager] = [:]

    private var hotKeyRefs: [ShortcutID: EventHotKeyRef] = [:]
    private var actions: [ShortcutID: () -> Void] = [:]

    func registerGlobalShortcuts(
        toggleOverlay: @escaping () -> Void,
        togglePlayback: @escaping () -> Void,
        stopPlayback: @escaping () -> Void,
        restartPlayback: @escaping () -> Void,
        increaseSpeed: @escaping () -> Void,
        decreaseSpeed: @escaping () -> Void
    ) {
        unregisterGlobalShortcuts()
        installHandlerIfNeeded()

        actions = [
            .toggleOverlay: toggleOverlay,
            .togglePlayback: togglePlayback,
            .stopPlayback: stopPlayback,
            .restartPlayback: restartPlayback,
            .increaseSpeed: increaseSpeed,
            .decreaseSpeed: decreaseSpeed,
        ]

        Self.sharedManagers[ObjectIdentifier(self)] = self

        let modifiers = UInt32(cmdKey | shiftKey)
        registerHotKey(.toggleOverlay, keyCode: UInt32(kVK_ANSI_O), modifiers: modifiers)
        registerHotKey(.togglePlayback, keyCode: UInt32(kVK_ANSI_P), modifiers: modifiers)
        registerHotKey(.stopPlayback, keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers)
        registerHotKey(.restartPlayback, keyCode: UInt32(kVK_Return), modifiers: modifiers)
        registerHotKey(.increaseSpeed, keyCode: UInt32(kVK_ANSI_Equal), modifiers: modifiers)
        registerHotKey(.decreaseSpeed, keyCode: UInt32(kVK_ANSI_Minus), modifiers: modifiers)
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
        let hotKeyRefs = hotKeyRefs.values
        let identifier = ObjectIdentifier(self)
        Task { @MainActor in
            for ref in hotKeyRefs {
                UnregisterEventHotKey(ref)
            }
            Self.sharedManagers.removeValue(forKey: identifier)
        }
    }

    private func registerHotKey(_ id: ShortcutID, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: id.rawValue)

        RegisterEventHotKey(
            keyCode,
            modifiers,
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

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

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
