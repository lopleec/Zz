import SwiftUI
import AppKit

// MARK: - Floating Panel (NSPanel subclass)

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        self.animationBehavior = .utilityWindow

        self.contentView = contentView
        positionAtBottomLeft()
    }

    func positionAtBottomLeft() {
        guard let screen = getLeftmostScreen() else { return }
        let padding: CGFloat = 12
        let x = screen.visibleFrame.minX + padding
        let y = screen.visibleFrame.minY + padding
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func toggleVisibility() {
        if isVisible {
            hideWithAnimation()
        } else {
            showWithAnimation()
        }
    }

    func showWithAnimation() {
        positionAtBottomLeft()
        alphaValue = 0
        orderFrontRegardless()
        makeKey()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func hideWithAnimation() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    private func getLeftmostScreen() -> NSScreen? {
        NSScreen.screens.min(by: { $0.frame.minX < $1.frame.minX }) ?? NSScreen.main
    }
}
