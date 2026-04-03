import Foundation
import SwiftTerm

/// RTL-aware input handler — queries current line direction for arrow key remapping.
class BiDiInputHandler {

    /// Determine the paragraph direction of the current line
    static func currentLineDirection(terminal: Terminal) -> BiDiDirection {
        let buffer = terminal.buffer
        let row = buffer.y
        guard let line = terminal.getLine(row: row) else { return .ltr }
        let text = line.translateToString()
        return BiDiLineAnalyzer.paragraphDirection(text)
    }

}
