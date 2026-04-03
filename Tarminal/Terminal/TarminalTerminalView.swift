import AppKit
import SwiftTerm

/// Subclass of LocalProcessTerminalView to control bell behavior.
/// We override bell(source: Terminal) which is the TerminalDelegate method
/// marked `open` on MacTerminalView. This is the actual entry point —
/// MacTerminalView.bell(source:Terminal) is called by the Terminal,
/// and the default impl forwards to terminalDelegate?.bell(source:TerminalView).
/// By overriding at this level we intercept before that forwarding happens.
class TarminalTerminalView: LocalProcessTerminalView {

    /// Whether terminal bell plays a sound
    var bellSoundEnabled: Bool = true

    /// Whether terminal bell bounces the dock icon
    var bellBounceEnabled: Bool = false

    // Override the TerminalDelegate.bell entry point (marked `open` on MacTerminalView)
    override open func bell(source: Terminal) {
        if bellSoundEnabled {
            NSSound.beep()
        }
        if bellBounceEnabled {
            NSApp.requestUserAttention(.informationalRequest)
        }
        // Do NOT call super — super unconditionally calls terminalDelegate?.bell()
        // which would beep again via the default extension
    }
}
