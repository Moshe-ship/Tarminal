import AppKit
import SwiftTerm

/// Custom terminal view: bell control, Metal rendering, notifications.
class TarminalTerminalView: LocalProcessTerminalView {

    var bellSoundEnabled: Bool = true
    var bellBounceEnabled: Bool = false
    var tabTitle: String = "zsh"

    func enableMetal() {
        do { try setUseMetal(true) } catch {}
    }

    override open func bell(source: Terminal) {
        if bellSoundEnabled { NSSound.beep() }
        if bellBounceEnabled { NSApp.requestUserAttention(.informationalRequest) }
        NotificationManager.shared.notifyBell(tabTitle: tabTitle)
    }
}
