import AppKit
import Carbon
import SwiftData
import SwiftUI

struct AppShortcut: Equatable {
    enum Key: String, CaseIterable, Identifiable {
        case a, b, c, d, e, f, g, h, i, j, k, l, m
        case n, o, p, q, r, s, t, u, v, w, x, y, z
        case zero = "0"
        case one = "1"
        case two = "2"
        case three = "3"
        case four = "4"
        case five = "5"
        case six = "6"
        case seven = "7"
        case eight = "8"
        case nine = "9"
        case space
        case `return`
        case period
        case minus
        case equal
        case upArrow
        case downArrow
        case commandKey
        case shiftKey
        case optionKey
        case controlKey

        var id: String { rawValue }

        var label: String {
            switch self {
            case .space:
                return "Space"
            case .return:
                return "Return"
            case .period:
                return "."
            case .minus:
                return "-"
            case .equal:
                return "="
            case .upArrow:
                return "Up"
            case .downArrow:
                return "Down"
            case .commandKey:
                return "Command"
            case .shiftKey:
                return "Shift"
            case .optionKey:
                return "Option"
            case .controlKey:
                return "Control"
            default:
                return rawValue.uppercased()
            }
        }

        var keyEquivalent: KeyEquivalent {
            switch self {
            case .space:
                return .space
            case .return:
                return .return
            case .upArrow:
                return .upArrow
            case .downArrow:
                return .downArrow
            case .commandKey, .shiftKey, .optionKey, .controlKey:
                return .space
            default:
                return KeyEquivalent(Character(rawValue))
            }
        }

        var carbonKeyCode: UInt32 {
            switch self {
            case .a: return UInt32(kVK_ANSI_A)
            case .b: return UInt32(kVK_ANSI_B)
            case .c: return UInt32(kVK_ANSI_C)
            case .d: return UInt32(kVK_ANSI_D)
            case .e: return UInt32(kVK_ANSI_E)
            case .f: return UInt32(kVK_ANSI_F)
            case .g: return UInt32(kVK_ANSI_G)
            case .h: return UInt32(kVK_ANSI_H)
            case .i: return UInt32(kVK_ANSI_I)
            case .j: return UInt32(kVK_ANSI_J)
            case .k: return UInt32(kVK_ANSI_K)
            case .l: return UInt32(kVK_ANSI_L)
            case .m: return UInt32(kVK_ANSI_M)
            case .n: return UInt32(kVK_ANSI_N)
            case .o: return UInt32(kVK_ANSI_O)
            case .p: return UInt32(kVK_ANSI_P)
            case .q: return UInt32(kVK_ANSI_Q)
            case .r: return UInt32(kVK_ANSI_R)
            case .s: return UInt32(kVK_ANSI_S)
            case .t: return UInt32(kVK_ANSI_T)
            case .u: return UInt32(kVK_ANSI_U)
            case .v: return UInt32(kVK_ANSI_V)
            case .w: return UInt32(kVK_ANSI_W)
            case .x: return UInt32(kVK_ANSI_X)
            case .y: return UInt32(kVK_ANSI_Y)
            case .z: return UInt32(kVK_ANSI_Z)
            case .zero: return UInt32(kVK_ANSI_0)
            case .one: return UInt32(kVK_ANSI_1)
            case .two: return UInt32(kVK_ANSI_2)
            case .three: return UInt32(kVK_ANSI_3)
            case .four: return UInt32(kVK_ANSI_4)
            case .five: return UInt32(kVK_ANSI_5)
            case .six: return UInt32(kVK_ANSI_6)
            case .seven: return UInt32(kVK_ANSI_7)
            case .eight: return UInt32(kVK_ANSI_8)
            case .nine: return UInt32(kVK_ANSI_9)
            case .space: return UInt32(kVK_Space)
            case .return: return UInt32(kVK_Return)
            case .period: return UInt32(kVK_ANSI_Period)
            case .minus: return UInt32(kVK_ANSI_Minus)
            case .equal: return UInt32(kVK_ANSI_Equal)
            case .upArrow: return UInt32(kVK_UpArrow)
            case .downArrow: return UInt32(kVK_DownArrow)
            case .commandKey: return UInt32(kVK_Command)
            case .shiftKey: return UInt32(kVK_Shift)
            case .optionKey: return UInt32(kVK_Option)
            case .controlKey: return UInt32(kVK_Control)
            }
        }

        init?(carbonKeyCode: UInt32) {
            switch carbonKeyCode {
            case UInt32(kVK_ANSI_A): self = .a
            case UInt32(kVK_ANSI_B): self = .b
            case UInt32(kVK_ANSI_C): self = .c
            case UInt32(kVK_ANSI_D): self = .d
            case UInt32(kVK_ANSI_E): self = .e
            case UInt32(kVK_ANSI_F): self = .f
            case UInt32(kVK_ANSI_G): self = .g
            case UInt32(kVK_ANSI_H): self = .h
            case UInt32(kVK_ANSI_I): self = .i
            case UInt32(kVK_ANSI_J): self = .j
            case UInt32(kVK_ANSI_K): self = .k
            case UInt32(kVK_ANSI_L): self = .l
            case UInt32(kVK_ANSI_M): self = .m
            case UInt32(kVK_ANSI_N): self = .n
            case UInt32(kVK_ANSI_O): self = .o
            case UInt32(kVK_ANSI_P): self = .p
            case UInt32(kVK_ANSI_Q): self = .q
            case UInt32(kVK_ANSI_R): self = .r
            case UInt32(kVK_ANSI_S): self = .s
            case UInt32(kVK_ANSI_T): self = .t
            case UInt32(kVK_ANSI_U): self = .u
            case UInt32(kVK_ANSI_V): self = .v
            case UInt32(kVK_ANSI_W): self = .w
            case UInt32(kVK_ANSI_X): self = .x
            case UInt32(kVK_ANSI_Y): self = .y
            case UInt32(kVK_ANSI_Z): self = .z
            case UInt32(kVK_ANSI_0): self = .zero
            case UInt32(kVK_ANSI_1): self = .one
            case UInt32(kVK_ANSI_2): self = .two
            case UInt32(kVK_ANSI_3): self = .three
            case UInt32(kVK_ANSI_4): self = .four
            case UInt32(kVK_ANSI_5): self = .five
            case UInt32(kVK_ANSI_6): self = .six
            case UInt32(kVK_ANSI_7): self = .seven
            case UInt32(kVK_ANSI_8): self = .eight
            case UInt32(kVK_ANSI_9): self = .nine
            case UInt32(kVK_Space): self = .space
            case UInt32(kVK_Return): self = .return
            case UInt32(kVK_ANSI_Period): self = .period
            case UInt32(kVK_ANSI_Minus): self = .minus
            case UInt32(kVK_ANSI_Equal): self = .equal
            case UInt32(kVK_UpArrow): self = .upArrow
            case UInt32(kVK_DownArrow): self = .downArrow
            case UInt32(kVK_Command), UInt32(kVK_RightCommand): self = .commandKey
            case UInt32(kVK_Shift), UInt32(kVK_RightShift): self = .shiftKey
            case UInt32(kVK_Option), UInt32(kVK_RightOption): self = .optionKey
            case UInt32(kVK_Control), UInt32(kVK_RightControl): self = .controlKey
            default: return nil
            }
        }

        var modifierFlag: NSEvent.ModifierFlags? {
            switch self {
            case .commandKey:
                return .command
            case .shiftKey:
                return .shift
            case .optionKey:
                return .option
            case .controlKey:
                return .control
            default:
                return nil
            }
        }

        var isModifierKey: Bool {
            modifierFlag != nil
        }
    }

    struct Modifiers: OptionSet, Equatable {
        let rawValue: Int

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)

        var eventModifiers: SwiftUI.EventModifiers {
            var modifiers: SwiftUI.EventModifiers = []
            if contains(.command) { modifiers.insert(.command) }
            if contains(.shift) { modifiers.insert(.shift) }
            if contains(.option) { modifiers.insert(.option) }
            if contains(.control) { modifiers.insert(.control) }
            return modifiers
        }

        var carbonModifiers: UInt32 {
            var modifiers: UInt32 = 0
            if contains(.command) { modifiers |= UInt32(cmdKey) }
            if contains(.shift) { modifiers |= UInt32(shiftKey) }
            if contains(.option) { modifiers |= UInt32(optionKey) }
            if contains(.control) { modifiers |= UInt32(controlKey) }
            return modifiers
        }

        var label: String {
            let parts = [
                contains(.command) ? "Cmd" : nil,
                contains(.shift) ? "Shift" : nil,
                contains(.option) ? "Option" : nil,
                contains(.control) ? "Control" : nil,
            ].compactMap { $0 }

            return parts.joined(separator: "+")
        }

        init(eventModifierFlags: NSEvent.ModifierFlags) {
            var modifiers: Modifiers = []
            if eventModifierFlags.contains(.command) { modifiers.insert(.command) }
            if eventModifierFlags.contains(.shift) { modifiers.insert(.shift) }
            if eventModifierFlags.contains(.option) { modifiers.insert(.option) }
            if eventModifierFlags.contains(.control) { modifiers.insert(.control) }
            self = modifiers
        }
    }

    var key: Key
    var modifiers: Modifiers

    var displayName: String {
        let modifierLabel = modifiers.label
        return modifierLabel.isEmpty ? key.label : "\(modifierLabel)+\(key.label)"
    }

    static let unassigned = AppShortcut(key: .space, modifiers: [])
}

enum AppShortcutCommand: String, CaseIterable, Identifiable {
    case toggleOverlay
    case togglePlayback
    case holdToScroll
    case stopPlayback
    case restartPlayback
    case increaseSpeed
    case decreaseSpeed
    case stepForward
    case stepBackward

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleOverlay:
            return "Toggle overlay"
        case .togglePlayback:
            return "Toggle autoplay"
        case .holdToScroll:
            return "Hold to scroll"
        case .stopPlayback:
            return "Stop autoplay"
        case .restartPlayback:
            return "Restart from top"
        case .increaseSpeed:
            return "Increase speed"
        case .decreaseSpeed:
            return "Decrease speed"
        case .stepForward:
            return "Step forward"
        case .stepBackward:
            return "Step backward"
        }
    }

    var subtitle: String {
        switch self {
        case .toggleOverlay:
            return "Show or hide the teleprompter overlay window"
        case .togglePlayback:
            return "Start or pause autoplay in the overlay"
        case .holdToScroll:
            return "Move the teleprompter text only while the shortcut is held down"
        case .stopPlayback:
            return "Stop autoplay and reset the overlay position"
        case .restartPlayback:
            return "Return the active script to the beginning"
        case .increaseSpeed:
            return "Increase the autoplay words-per-minute speed"
        case .decreaseSpeed:
            return "Decrease the autoplay words-per-minute speed"
        case .stepForward:
            return "Move the teleprompter text forward one step"
        case .stepBackward:
            return "Move the teleprompter text backward one step"
        }
    }

    var isEditable: Bool {
        switch self {
        case .toggleOverlay, .togglePlayback, .holdToScroll:
            return true
        case .stopPlayback, .restartPlayback, .increaseSpeed, .decreaseSpeed, .stepForward, .stepBackward:
            return false
        }
    }

    var defaultShortcut: AppShortcut {
        switch self {
        case .toggleOverlay:
            return AppShortcut(key: .o, modifiers: [.command, .shift])
        case .togglePlayback:
            return AppShortcut(key: .p, modifiers: [.command, .shift])
        case .holdToScroll:
            return AppShortcut(key: .space, modifiers: [])
        case .stopPlayback:
            return AppShortcut(key: .s, modifiers: [.command, .shift])
        case .restartPlayback:
            return AppShortcut(key: .return, modifiers: [.command, .shift])
        case .increaseSpeed:
            return AppShortcut(key: .equal, modifiers: [.command, .shift])
        case .decreaseSpeed:
            return AppShortcut(key: .minus, modifiers: [.command, .shift])
        case .stepForward:
            return AppShortcut(key: .downArrow, modifiers: [.option])
        case .stepBackward:
            return AppShortcut(key: .upArrow, modifiers: [.option])
        }
    }
}

struct AppSettingsSnapshot: Equatable {
    var fontName: String
    var fontSize: Double
    var lineSpacing: Double
    var overlayOpacity: Double
    var playbackSpeedWordsPerMinute: Double
    var showDockIcon: Bool
    var showMenuBarItem: Bool
    var keepOverlayCentered: Bool
    var toggleOverlayShortcut: AppShortcut
    var togglePlaybackShortcut: AppShortcut
    var holdToScrollShortcut: AppShortcut

    init(settings: AppSettings) {
        fontName = settings.fontName
        fontSize = settings.fontSize
        lineSpacing = settings.lineSpacing
        overlayOpacity = settings.overlayOpacity
        playbackSpeedWordsPerMinute = settings.playbackSpeedWordsPerMinute
        showDockIcon = settings.showDockIcon
        showMenuBarItem = settings.showMenuBarItem
        keepOverlayCentered = settings.keepOverlayCentered
        toggleOverlayShortcut = settings.toggleOverlayShortcut
        togglePlaybackShortcut = settings.togglePlaybackShortcut
        holdToScrollShortcut = settings.holdToScrollShortcut
    }

    static let `default` = AppSettingsSnapshot(settings: AppSettings())

    var resolvedFont: Font {
        let fontSize = max(fontSize, 1)
        if let nsFont = NSFont(name: fontName, size: fontSize) {
            return Font(nsFont)
        }
        return .system(size: fontSize, weight: .medium, design: .rounded)
    }
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var fontName: String
    var fontSize: Double
    var lineSpacing: Double
    var overlayOpacity: Double
    var playbackSpeedWordsPerMinute: Double
    var showDockIcon: Bool
    var showMenuBarItem: Bool
    var keepOverlayCentered: Bool
    var toggleOverlayShortcutKey: String
    var toggleOverlayShortcutModifiersRawValue: Int
    var togglePlaybackShortcutKey: String
    var togglePlaybackShortcutModifiersRawValue: Int
    var holdToScrollShortcutKey: String?
    var holdToScrollShortcutModifiersRawValue: Int?

    init(
        id: String = "default-settings",
        fontName: String = "SF Pro",
        fontSize: Double = 42,
        lineSpacing: Double = 12,
        overlayOpacity: Double = 0.92,
        playbackSpeedWordsPerMinute: Double = 140,
        showDockIcon: Bool = true,
        showMenuBarItem: Bool = true,
        keepOverlayCentered: Bool = true,
        toggleOverlayShortcutKey: String = AppShortcut.Key.o.rawValue,
        toggleOverlayShortcutModifiersRawValue: Int = AppShortcut.Modifiers.command.union(.shift).rawValue,
        togglePlaybackShortcutKey: String = AppShortcut.Key.p.rawValue,
        togglePlaybackShortcutModifiersRawValue: Int = AppShortcut.Modifiers.command.union(.shift).rawValue,
        holdToScrollShortcutKey: String? = AppShortcut.Key.space.rawValue,
        holdToScrollShortcutModifiersRawValue: Int? = AppShortcut.Modifiers().rawValue
    ) {
        self.id = id
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.overlayOpacity = overlayOpacity
        self.playbackSpeedWordsPerMinute = playbackSpeedWordsPerMinute
        self.showDockIcon = showDockIcon
        self.showMenuBarItem = showMenuBarItem
        self.keepOverlayCentered = keepOverlayCentered
        self.toggleOverlayShortcutKey = toggleOverlayShortcutKey
        self.toggleOverlayShortcutModifiersRawValue = toggleOverlayShortcutModifiersRawValue
        self.togglePlaybackShortcutKey = togglePlaybackShortcutKey
        self.togglePlaybackShortcutModifiersRawValue = togglePlaybackShortcutModifiersRawValue
        self.holdToScrollShortcutKey = holdToScrollShortcutKey
        self.holdToScrollShortcutModifiersRawValue = holdToScrollShortcutModifiersRawValue
    }

    var toggleOverlayShortcut: AppShortcut {
        get {
            AppShortcut(
                key: AppShortcut.Key(rawValue: toggleOverlayShortcutKey) ?? .o,
                modifiers: AppShortcut.Modifiers(rawValue: max(toggleOverlayShortcutModifiersRawValue, 0))
            )
        }
        set {
            toggleOverlayShortcutKey = newValue.key.rawValue
            toggleOverlayShortcutModifiersRawValue = newValue.modifiers.rawValue
        }
    }

    var togglePlaybackShortcut: AppShortcut {
        get {
            AppShortcut(
                key: AppShortcut.Key(rawValue: togglePlaybackShortcutKey) ?? .p,
                modifiers: AppShortcut.Modifiers(rawValue: max(togglePlaybackShortcutModifiersRawValue, 0))
            )
        }
        set {
            togglePlaybackShortcutKey = newValue.key.rawValue
            togglePlaybackShortcutModifiersRawValue = newValue.modifiers.rawValue
        }
    }

    var holdToScrollShortcut: AppShortcut {
        get {
            AppShortcut(
                key: AppShortcut.Key(rawValue: holdToScrollShortcutKey ?? AppShortcut.Key.controlKey.rawValue) ?? .controlKey,
                modifiers: AppShortcut.Modifiers(rawValue: max(holdToScrollShortcutModifiersRawValue ?? 0, 0))
            )
        }
        set {
            holdToScrollShortcutKey = newValue.key.rawValue
            holdToScrollShortcutModifiersRawValue = newValue.modifiers.rawValue
        }
    }

    var snapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: self)
    }

    var isToggleOverlayShortcutAssigned: Bool {
        toggleOverlayShortcutModifiersRawValue >= 0
    }

    var isTogglePlaybackShortcutAssigned: Bool {
        togglePlaybackShortcutModifiersRawValue >= 0
    }

    var isHoldToScrollShortcutAssigned: Bool {
        (holdToScrollShortcutModifiersRawValue ?? 0) >= 0
    }
}
