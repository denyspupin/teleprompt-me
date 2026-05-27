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
    private var holdShortcut: AppShortcut?
    private var holdShortcutDownHandler: (() -> Void)?
    private var holdShortcutUpHandler: (() -> Void)?
    private var isHoldShortcutPressed = false
    private var localEventMonitor: Any?

    func registerGlobalShortcuts(
        toggleOverlayShortcut: AppShortcut,
        togglePlaybackShortcut: AppShortcut,
        holdToScrollShortcut: AppShortcut,
        isToggleOverlayShortcutEnabled: Bool,
        isTogglePlaybackShortcutEnabled: Bool,
        isHoldToScrollShortcutEnabled: Bool,
        toggleOverlay: @escaping () -> Void,
        togglePlayback: @escaping () -> Void,
        beginHoldToScroll: @escaping () -> Void,
        endHoldToScroll: @escaping () -> Void,
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
        holdShortcut = isHoldToScrollShortcutEnabled ? holdToScrollShortcut : nil
        holdShortcutDownHandler = beginHoldToScroll
        holdShortcutUpHandler = endHoldToScroll
        installEventMonitorsIfNeeded()

        let fixedModifiers = UInt32(cmdKey | shiftKey)
        if isToggleOverlayShortcutEnabled {
            registerHotKey(
                .toggleOverlay,
                keyCode: toggleOverlayShortcut.key.carbonKeyCode,
                modifiers: toggleOverlayShortcut.modifiers.carbonModifiers
            )
        }
        if isTogglePlaybackShortcutEnabled {
            registerHotKey(
                .togglePlayback,
                keyCode: togglePlaybackShortcut.key.carbonKeyCode,
                modifiers: togglePlaybackShortcut.modifiers.carbonModifiers
            )
        }
        registerHotKey(.stopPlayback, keyCode: UInt32(kVK_ANSI_S), modifiers: fixedModifiers)
        registerHotKey(.restartPlayback, keyCode: UInt32(kVK_Return), modifiers: fixedModifiers)
        registerHotKey(.increaseSpeed, keyCode: UInt32(kVK_ANSI_Equal), modifiers: fixedModifiers)
        registerHotKey(.decreaseSpeed, keyCode: UInt32(kVK_ANSI_Minus), modifiers: fixedModifiers)
    }

    func unregisterGlobalShortcuts() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }

        if isHoldShortcutPressed {
            holdShortcutUpHandler?()
        }

        hotKeyRefs.removeAll()
        actions.removeAll()
        holdShortcut = nil
        holdShortcutDownHandler = nil
        holdShortcutUpHandler = nil
        isHoldShortcutPressed = false
        Self.sharedManagers.removeValue(forKey: ObjectIdentifier(self))
    }

    deinit {
        let hotKeyRefs = hotKeyRefs.values
        let identifier = ObjectIdentifier(self)
        let localEventMonitor = localEventMonitor
        Task { @MainActor in
            for ref in hotKeyRefs {
                UnregisterEventHotKey(ref)
            }
            if let localEventMonitor {
                NSEvent.removeMonitor(localEventMonitor)
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

    private func installEventMonitorsIfNeeded() {
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
                let shouldConsume = self?.handleMonitoredEvent(event) ?? false
                return shouldConsume ? nil : event
            }
        }
    }

    @discardableResult
    private func handleMonitoredEvent(_ event: NSEvent) -> Bool {
        guard let holdShortcut else { return false }
        guard event.keyCode == holdShortcut.key.carbonKeyCode else { return false }

        if holdShortcut.key.isModifierKey {
            return handleModifierOnlyShortcutEvent(event, shortcut: holdShortcut)
        }

        switch event.type {
        case .keyDown:
            guard modifiersMatch(event.modifierFlags, shortcutModifiers: holdShortcut.modifiers) else { return false }
            if !event.isARepeat, !isHoldShortcutPressed {
                isHoldShortcutPressed = true
                holdShortcutDownHandler?()
            }
            return true
        case .keyUp:
            guard isHoldShortcutPressed else { return false }
            isHoldShortcutPressed = false
            holdShortcutUpHandler?()
            return true
        default:
            return false
        }
    }

    private func handleModifierOnlyShortcutEvent(_ event: NSEvent, shortcut: AppShortcut) -> Bool {
        guard event.type == .flagsChanged, let keyModifierFlag = shortcut.key.modifierFlag else { return false }

        var expectedFlags = shortcut.modifiers
        expectedFlags.formUnion(AppShortcut.Modifiers(eventModifierFlags: keyModifierFlag))

        let currentFlags = AppShortcut.Modifiers(
            eventModifierFlags: event.modifierFlags.intersection([.command, .shift, .option, .control])
        )
        let isActive = currentFlags == expectedFlags

        if isActive {
            if !isHoldShortcutPressed {
                isHoldShortcutPressed = true
                holdShortcutDownHandler?()
            }
            return true
        }

        if isHoldShortcutPressed {
            isHoldShortcutPressed = false
            holdShortcutUpHandler?()
            return true
        }

        return false
    }

    private func modifiersMatch(_ eventModifiers: NSEvent.ModifierFlags, shortcutModifiers: AppShortcut.Modifiers) -> Bool {
        let relevantFlags = eventModifiers.intersection([.command, .shift, .option, .control])
        return AppShortcut.Modifiers(eventModifierFlags: relevantFlags) == shortcutModifiers
    }
}
