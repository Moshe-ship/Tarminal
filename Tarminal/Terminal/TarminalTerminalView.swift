import AppKit
import SwiftTerm

/// Subclass of LocalProcessTerminalView for:
/// - Bell control (sound + dock bounce)
/// - Metal GPU rendering
/// - RTL-aware arrow key remapping (first of its kind)
class TarminalTerminalView: LocalProcessTerminalView {

    var bellSoundEnabled: Bool = true
    var bellBounceEnabled: Bool = false
    var arabicFontName: String = "GeezaPro"
    var bidiMode: String = "auto"

    func enableMetal() {
        do {
            try setUseMetal(true)
        } catch {
            // Metal not available — CoreGraphics fallback
        }
    }

    // MARK: - Bell

    override open func bell(source: Terminal) {
        if bellSoundEnabled {
            NSSound.beep()
        }
        if bellBounceEnabled {
            NSApp.requestUserAttention(.informationalRequest)
        }
    }

    // MARK: - RTL Arrow Key Remapping

    private var currentLineIsRTL: Bool {
        guard bidiMode != "ltr" else { return false }
        let terminal = getTerminal()
        if bidiMode == "rtl" { return true }
        return BiDiInputHandler.currentLineDirection(terminal: terminal) == .rtl
    }

    // Left arrow: on RTL line, move cursor logically forward (visually left = forward in RTL)
    override open func moveLeft(_ sender: Any?) {
        if currentLineIsRTL {
            let terminal = getTerminal()
            send(terminal.applicationCursor ? EscapeSequences.moveRightApp : EscapeSequences.moveRightNormal)
        } else {
            super.moveLeft(sender)
        }
    }

    // Right arrow: on RTL line, move cursor logically backward
    override open func moveRight(_ sender: Any?) {
        if currentLineIsRTL {
            let terminal = getTerminal()
            send(terminal.applicationCursor ? EscapeSequences.moveLeftApp : EscapeSequences.moveLeftNormal)
        } else {
            super.moveRight(sender)
        }
    }

    // Home key: on RTL line, go to logical end (visual start = right edge)
    override open func moveToBeginningOfLine(_ sender: Any?) {
        if currentLineIsRTL {
            // Send Ctrl+E (end of line in readline/zsh)
            send([0x05])
        } else {
            super.moveToBeginningOfLine(sender)
        }
    }

    // End key: on RTL line, go to logical beginning (visual end = left edge)
    override open func moveToEndOfLine(_ sender: Any?) {
        if currentLineIsRTL {
            // Send Ctrl+A (beginning of line in readline/zsh)
            send([0x01])
        } else {
            super.moveToEndOfLine(sender)
        }
    }
}
