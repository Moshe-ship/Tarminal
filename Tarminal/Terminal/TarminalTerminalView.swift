import AppKit
import SwiftTerm

/// Custom terminal view: bell control, RTL sublayer, arrow key remapping.
class TarminalTerminalView: LocalProcessTerminalView {

    var bellSoundEnabled: Bool = true
    var bellBounceEnabled: Bool = false
    var arabicFontName: String = "GeezaPro"
    var bidiMode: String = "auto"

    private var bidiLayer: BiDiLayer?
    private var refreshTimer: Timer?

    func enableMetal() {
        do { try setUseMetal(true) } catch {}
    }

    /// Set up the BiDi sublayer after the view is in a window
    func setupBiDiLayer() {
        guard bidiLayer == nil else { return }
        wantsLayer = true
        let layer = BiDiLayer()
        layer.terminalView = self
        layer.frame = self.bounds
        layer.contentsScale = window?.backingScaleFactor ?? 2.0
        layer.needsDisplayOnBoundsChange = true
        self.layer?.addSublayer(layer)
        bidiLayer = layer

        // Refresh the BiDi layer periodically to track terminal output
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.bidiLayer?.frame = self?.bounds ?? .zero
            self?.bidiLayer?.setNeedsDisplay()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupBiDiLayer()
        }
    }

    override func layout() {
        super.layout()
        bidiLayer?.frame = bounds
        bidiLayer?.contentsScale = window?.backingScaleFactor ?? 2.0
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Bell

    override open func bell(source: Terminal) {
        if bellSoundEnabled { NSSound.beep() }
        if bellBounceEnabled { NSApp.requestUserAttention(.informationalRequest) }
    }

    // MARK: - RTL Arrow Key Remapping

    private var currentLineIsRTL: Bool {
        guard bidiMode != "ltr" else { return false }
        let terminal = getTerminal()
        if terminal.isCurrentBufferAlternate { return false }
        if bidiMode == "rtl" { return true }
        return BiDiInputHandler.currentLineDirection(terminal: terminal) == .rtl
    }

    override open func moveLeft(_ sender: Any?) {
        if currentLineIsRTL {
            send(getTerminal().applicationCursor ? EscapeSequences.moveRightApp : EscapeSequences.moveRightNormal)
        } else {
            super.moveLeft(sender)
        }
    }

    override open func moveRight(_ sender: Any?) {
        if currentLineIsRTL {
            send(getTerminal().applicationCursor ? EscapeSequences.moveLeftApp : EscapeSequences.moveLeftNormal)
        } else {
            super.moveRight(sender)
        }
    }

    override open func moveToBeginningOfLine(_ sender: Any?) {
        if currentLineIsRTL { send([0x05]) } else { super.moveToBeginningOfLine(sender) }
    }

    override open func moveToEndOfLine(_ sender: Any?) {
        if currentLineIsRTL { send([0x01]) } else { super.moveToEndOfLine(sender) }
    }
}
