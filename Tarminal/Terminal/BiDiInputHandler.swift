import AppKit
import SwiftTerm
import CoreText

/// RTL-aware input handler for terminal line editing.
///
/// Standard terminals treat all text as LTR — arrow keys always move the logical cursor
/// left/right regardless of text direction. This handler intercepts cursor movement
/// on lines with RTL content and remaps keys to visual direction:
///
/// - Left arrow → moves cursor visually left (logically RIGHT in RTL text)
/// - Right arrow → moves cursor visually right (logically LEFT in RTL text)
/// - Home → visual start of line (right edge for RTL)
/// - End → visual end of line (left edge for RTL)
///
/// It also computes the visual cursor position for RTL lines so the BiDi overlay
/// can draw the cursor at the correct screen position.
class BiDiInputHandler {

    /// Determine if the current line in the terminal has RTL content
    static func currentLineIsRTL(terminal: Terminal) -> Bool {
        let buffer = terminal.buffer
        let row = buffer.y
        guard let line = terminal.getLine(row: row) else { return false }
        let text = line.translateToString()
        return BiDiLineAnalyzer.containsRTL(text)
    }

    /// Determine the paragraph direction of the current line
    static func currentLineDirection(terminal: Terminal) -> BiDiDirection {
        let buffer = terminal.buffer
        let row = buffer.y
        guard let line = terminal.getLine(row: row) else { return .ltr }
        let text = line.translateToString()
        return BiDiLineAnalyzer.paragraphDirection(text)
    }

    /// Compute the visual X position for the cursor on an RTL line.
    /// Uses Core Text's CTLine to map logical buffer.x → visual screen X.
    ///
    /// Returns the visual X offset in points, or nil if the line is not RTL.
    static func visualCursorX(
        terminal: Terminal,
        font: NSFont,
        arabicFontName: String,
        cellWidth: CGFloat
    ) -> CGFloat? {
        let buffer = terminal.buffer
        let row = buffer.y
        let logicalX = buffer.x

        guard let line = terminal.getLine(row: row) else { return nil }
        let text = line.translateToString()

        guard BiDiLineAnalyzer.containsRTL(text) else { return nil }

        let direction = BiDiLineAnalyzer.paragraphDirection(text)
        guard direction == .rtl else { return nil }

        // Build attributed string matching the overlay's font cascade
        let fontSize = font.pointSize
        let ctFont = CTFontCreateWithName(font.fontName as CFString, fontSize, nil)
        let arabicDesc = CTFontDescriptorCreateWithNameAndSize(arabicFontName as CFString, fontSize)
        let cascadeAttrs: [CFString: Any] = [kCTFontCascadeListAttribute: [arabicDesc]]
        let mergedDesc = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(ctFont),
            cascadeAttrs as CFDictionary
        )
        let cascadeFont = CTFontCreateWithFontDescriptor(mergedDesc, fontSize, nil)

        let attrString = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): cascadeFont,
                .paragraphStyle: {
                    let ps = NSMutableParagraphStyle()
                    ps.baseWritingDirection = .rightToLeft
                    ps.alignment = .right
                    return ps
                }()
            ]
        )

        let ctLine = CTLineCreateWithAttributedString(attrString)

        // Map logical string index to visual X offset
        let clampedIndex = min(logicalX, text.count)
        let visualOffset = CTLineGetOffsetForStringIndex(ctLine, clampedIndex, nil)

        // For RTL lines rendered right-aligned, offset from right edge
        let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
        let cols = terminal.cols
        let terminalWidth = CGFloat(cols) * cellWidth
        let lineStartX = terminalWidth - lineWidth

        return lineStartX + CGFloat(visualOffset)
    }
}
