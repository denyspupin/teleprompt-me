import AppKit
import SwiftUI

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowManager {
    private enum Layout {
        static let notchWidthEstimate: CGFloat = 320
        static let defaultHeight: CGFloat = 220
        static let minimumWidth: CGFloat = 560
        static let maximumWidth: CGFloat = 760
        static let topPadding: CGFloat = 10
    }

    private var window: NSPanel?
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    var isInteractive: Bool = false {
        didSet {
            updateInteractivity()
        }
    }

    func present(appState: AppState) {
        if window == nil {
            let defaultFrame = defaultPanelFrame()
            let contentView = TeleprompterOverlayView()
                .environment(appState)
            let hostingController = NSHostingController(rootView: contentView)

            let panel = OverlayPanel(
                contentRect: defaultFrame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.becomesKeyOnlyIfNeeded = false
            panel.contentViewController = hostingController

            window = panel
        }

        if let window {
            applyDefaultLayout(to: window)
        }

        updateInteractivity()
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle(appState: AppState) {
        if isVisible {
            hide()
        } else {
            present(appState: appState)
        }
    }

    private func defaultPanelFrame() -> NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(x: 0, y: 0, width: 420, height: Layout.defaultHeight)
        }

        let width = min(
            max(Layout.notchWidthEstimate * 2, Layout.minimumWidth),
            min(Layout.maximumWidth, screen.frame.width * 0.5)
        )

        return NSRect(x: 0, y: 0, width: width, height: Layout.defaultHeight)
    }

    private func applyDefaultLayout(to panel: NSPanel) {
        let frame = defaultPanelFrame()
        panel.setContentSize(frame.size)
        panel.setFrame(frame, display: false)
        positionPanel(panel)
    }

    private func updateInteractivity() {
        guard let window else { return }
        window.ignoresMouseEvents = !isInteractive
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let x = screen.frame.midX - (panel.frame.width / 2)
        let topInset = screen.safeAreaInsets.top
        let y = screen.frame.maxY - topInset - panel.frame.height - Layout.topPadding
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
