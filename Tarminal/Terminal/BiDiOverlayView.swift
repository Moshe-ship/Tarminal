import AppKit
import SwiftTerm
import CoreText

/// Overlay view that re-renders lines containing RTL text using Core Text's native BiDi.
/// Uses the terminal's public API to access content, then renders via Core Text.
class BiDiOverlayView: NSView {
    weak var terminalView: TerminalView?
    private let cursorMapper = CursorMapper()
    private var cachedRTLRows: Set<Int> = []

    // Pass all mouse/keyboard events through to the terminal underneath
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // Makes this view completely transparent to input
    }

    // Cell dimensions (updated when terminal resizes)
    var cellWidth: CGFloat = 8
    var cellHeight: CGFloat = 16
    var fontSize: CGFloat = 14

    override var isFlipped: Bool { true }

    /// Update cell dimensions from the terminal font metrics
    func updateCellDimensions() {
        guard let tv = terminalView else { return }
        let font = tv.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let monoFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        var glyph = CTFontGetGlyphWithName(monoFont, "M" as CFString)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(monoFont, .horizontal, &glyph, &advance, 1)
        cellWidth = advance.width
        cellHeight = CTFontGetAscent(monoFont) + CTFontGetDescent(monoFont) + CTFontGetLeading(monoFont)
        fontSize = font.pointSize
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let terminalView = terminalView,
              let context = NSGraphicsContext.current?.cgContext else { return }

        let terminal = terminalView.getTerminal()
        let cols = terminal.cols
        let rows = terminal.rows

        updateCellDimensions()

        // Create fonts with Arabic cascade
        let monoFont = CTFontCreateWithName("SFMono-Regular" as CFString, fontSize, nil)
        let arabicDesc = CTFontDescriptorCreateWithNameAndSize("GeezaPro" as CFString, fontSize)
        let cascadeAttrs: [CFString: Any] = [kCTFontCascadeListAttribute: [arabicDesc]]
        let mergedDesc = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(monoFont),
            cascadeAttrs as CFDictionary
        )
        let cascadeFont = CTFontCreateWithFontDescriptor(mergedDesc, fontSize, nil)
        let baselineOffset = CTFontGetDescent(monoFont)

        for row in 0..<rows {
            // Use public API: getTerminal() gives us the Terminal object
            // Terminal has getLine(row:) which returns a BufferLine
            guard let line = terminal.getLine(row: row) else { continue }
            let lineText = line.translateToString()

            // Only process lines with RTL content — fast path for LTR
            guard BiDiLineAnalyzer.containsRTL(lineText) else {
                cachedRTLRows.remove(row)
                continue
            }

            cachedRTLRows.insert(row)

            let y = CGFloat(row) * cellHeight

            // Draw opaque black background to cover SwiftTerm's LTR rendering
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: y, width: bounds.width, height: cellHeight))

            // Build attributed string for the full line
            let attrString = NSMutableAttributedString(string: lineText)
            let fullRange = NSRange(location: 0, length: attrString.length)

            // Set cascade font
            attrString.addAttribute(
                NSAttributedString.Key(kCTFontAttributeName as String),
                value: cascadeFont,
                range: fullRange
            )

            // Default foreground color
            attrString.addAttribute(
                .foregroundColor,
                value: NSColor(white: 0.92, alpha: 1),
                range: fullRange
            )

            // Create CTLine — Core Text applies full UBA + Arabic shaping
            let ctLine = CTLineCreateWithAttributedString(attrString)

            // Draw text with proper coordinate transform for flipped view
            context.saveGState()
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = CGPoint(x: 0, y: y + cellHeight - baselineOffset)
            CTLineDraw(ctLine, context)
            context.restoreGState()

            // Update cursor mapping
            cursorMapper.updateMapping(row: row, text: lineText, font: cascadeFont)
        }
    }

    func hasRTLContent(row: Int) -> Bool {
        cachedRTLRows.contains(row)
    }
}
