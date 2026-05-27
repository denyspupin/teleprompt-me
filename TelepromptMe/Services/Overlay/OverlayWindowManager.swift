import AppKit
import SwiftUI

@MainActor
final class OverlayWindowManager {
    private var window: NSPanel?
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    var isInteractive: Bool = false {
        didSet {
            updateInteractivity()
        }
    }

    func present() {
        if window == nil {
            let contentView = TeleprompterOverlayView()
            let hostingController = NSHostingController(rootView: contentView)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 220),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentViewController = hostingController

            window = panel
            positionPanel(panel)
        }

        updateInteractivity()
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            present()
        }
    }

    private func updateInteractivity() {
        guard let window else { return }
        window.ignoresMouseEvents = !isInteractive
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let safeFrame = screen.visibleFrame.insetBy(dx: 0, dy: 16)
        let x = safeFrame.midX - (panel.frame.width / 2)
        let y = safeFrame.maxY - panel.frame.height - 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
