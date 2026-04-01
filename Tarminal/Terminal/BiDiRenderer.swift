import AppKit
import CoreText

/// Renders terminal lines with proper BiDi support using Core Text.
/// Core Text natively implements the full Unicode Bidirectional Algorithm (UBA),
/// Arabic shaping, ligatures, and connected letter rendering.
class BiDiRenderer {

    struct RenderConfig {
        let monoFont: CTFont
        let arabicFont: CTFont
        let cellWidth: CGFloat
        let cellHeight: CGFloat
        let baselineOffset: CGFloat
    }

    /// Create fonts with Arabic cascade fallback
    static func makeConfig(fontSize: CGFloat) -> RenderConfig {
        // Primary monospace font
        let monoFont = CTFontCreateWithName("SFMono-Regular" as CFString, fontSize, nil)

        // Arabic font for fallback
        let arabicFont = CTFontCreateWithName("GeezaPro" as CFString, fontSize, nil)

        // Create cascade font (mono + Arabic fallback)
        let cellWidth = CTFontGetAdvancesForGlyphs(
            monoFont, .horizontal,
            [CTFontGetGlyphWithName(monoFont, "M" as CFString)], nil, 1
        )
        let cellHeight = CTFontGetAscent(monoFont) + CTFontGetDescent(monoFont) + CTFontGetLeading(monoFont)
        let baselineOffset = CTFontGetDescent(monoFont)

        return RenderConfig(
            monoFont: monoFont,
            arabicFont: arabicFont,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            baselineOffset: baselineOffset
        )
    }

    /// Render a line that contains RTL content using Core Text's native BiDi.
    ///
    /// Instead of drawing character-by-character on a grid, we:
    /// 1. Build the full line as an NSAttributedString
    /// 2. Let Core Text create a CTLine (which applies UBA + Arabic shaping)
    /// 3. Draw backgrounds per-cell on the grid
    /// 4. Draw text via CTLineDraw (Core Text positions everything correctly)
    static func drawBiDiLine(
        text: String,
        foregroundColors: [(NSColor, NSRange)],
        backgroundColors: [(NSColor, Int)], // color per column
        row: Int,
        config: RenderConfig,
        context: CGContext,
        lineWidth: CGFloat
    ) {
        guard !text.isEmpty else { return }

        let y = CGFloat(row) * config.cellHeight

        // 1. Draw cell backgrounds
        for (color, col) in backgroundColors {
            if color != .black {
                context.setFillColor(color.cgColor)
                context.fill(CGRect(
                    x: CGFloat(col) * config.cellWidth,
                    y: y,
                    width: config.cellWidth,
                    height: config.cellHeight
                ))
            }
        }

        // 2. Build attributed string with font cascade
        let attrString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attrString.length)

        // Set base font (monospace)
        attrString.addAttribute(.font, value: config.monoFont, range: fullRange)

        // Apply per-segment foreground colors
        for (color, range) in foregroundColors {
            attrString.addAttribute(
                .foregroundColor,
                value: color,
                range: range
            )
        }

        // Apply Arabic font to RTL segments
        text.enumerated().forEach { (index, char) in
            for scalar in char.unicodeScalars {
                if BiDiLineAnalyzer.isRTL(scalar) {
                    let range = NSRange(location: index, length: 1)
                    attrString.addAttribute(.font, value: config.arabicFont, range: range)
                    break
                }
            }
        }

        // 3. Create CTLine — Core Text handles all BiDi reordering + Arabic shaping
        let ctLine = CTLineCreateWithAttributedString(attrString)

        // 4. Draw the text
        context.saveGState()
        context.textPosition = CGPoint(x: 0, y: y + config.baselineOffset)
        CTLineDraw(ctLine, context)
        context.restoreGState()
    }

    /// Map a visual x-position to a logical string index (for cursor/click mapping)
    static func logicalIndex(
        forVisualX x: CGFloat,
        in text: String,
        config: RenderConfig
    ) -> Int {
        let attrString = NSAttributedString(
            string: text,
            attributes: [.font: config.monoFont]
        )
        let ctLine = CTLineCreateWithAttributedString(attrString)
        return CTLineGetStringIndexForPosition(ctLine, CGPoint(x: x, y: 0))
    }

    /// Map a logical string index to a visual x-position (for cursor rendering)
    static func visualX(
        forLogicalIndex index: Int,
        in text: String,
        config: RenderConfig
    ) -> CGFloat {
        let attrString = NSAttributedString(
            string: text,
            attributes: [.font: config.monoFont]
        )
        let ctLine = CTLineCreateWithAttributedString(attrString)
        return CGFloat(CTLineGetOffsetForStringIndex(ctLine, index, nil))
    }
}
