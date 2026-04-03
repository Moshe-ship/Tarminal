import AppKit
import SwiftTerm
import CoreText

/// Overlay view that re-renders lines containing RTL text using Core Text's native BiDi.
/// Matches SwiftTerm's non-flipped coordinate system (Y=0 at bottom) for pixel-perfect alignment.
class BiDiOverlayView: NSView {
    weak var terminalView: TerminalView?

    /// BiDi mode: "auto" detects RTL per-line, "rtl" forces all lines RTL, "ltr" disables overlay
    var bidiMode: String = "auto"

    /// Arabic font name — kept in sync with ThemeManager
    var arabicFontName: String = "GeezaPro"

    // NOT flipped — matches SwiftTerm's coordinate system (Y=0 at bottom)
    override var isFlipped: Bool { false }

    // Pass all mouse/keyboard events through to the terminal underneath
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let terminalView = terminalView,
              let context = NSGraphicsContext.current?.cgContext else { return }

        // LTR mode = no overlay needed
        if bidiMode == "ltr" { return }

        let terminal = terminalView.getTerminal()

        // Don't touch alternate screen buffer — TUI apps (Claude Code, vim, htop,
        // less, man, etc.) handle their own rendering and cursor. BiDi overlay
        // only applies to normal shell output.
        if terminal.isCurrentBufferAlternate { return }
        let cols = terminal.cols
        let rows = terminal.rows

        // Match SwiftTerm's cell dimension calculation exactly:
        // Uses "W" glyph, snaps to backing pixel grid
        let font = terminalView.font
        let fontSize = font.pointSize
        let scale = terminalView.window?.backingScaleFactor ?? 2.0

        // Cell width: measure "W" advancement (same as SwiftTerm)
        let nsGlyph = font.glyph(withName: "W")
        let rawCellWidth = font.advancement(forGlyph: nsGlyph).width
        let cellWidth = ceil(rawCellWidth * scale) / scale

        // Cell height: ascent + descent + leading, snapped
        let ctFont = CTFontCreateWithName(font.fontName as CFString, fontSize, nil)
        let rawCellHeight = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont)
        let cellHeight = ceil(rawCellHeight * scale) / scale

        // Build cascade font: base mono + Arabic fallback
        let arabicDesc = CTFontDescriptorCreateWithNameAndSize(arabicFontName as CFString, fontSize)
        let cascadeAttrs: [CFString: Any] = [kCTFontCascadeListAttribute: [arabicDesc]]
        let mergedDesc = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(ctFont),
            cascadeAttrs as CFDictionary
        )
        let cascadeFont = CTFontCreateWithFontDescriptor(mergedDesc, fontSize, nil)

        let lineDescent = CTFontGetDescent(ctFont)
        let lineLeading = CTFontGetLeading(ctFont)
        let yOffset = ceil(lineDescent + lineLeading)

        for row in 0..<rows {
            guard let line = terminal.getLine(row: row) else { continue }
            let lineText = line.translateToString()

            // Determine if this line needs RTL rendering
            let needsRTL: Bool
            if bidiMode == "rtl" {
                needsRTL = !lineText.trimmingCharacters(in: .whitespaces).isEmpty
            } else {
                needsRTL = BiDiLineAnalyzer.containsRTL(lineText)
            }

            guard needsRTL else { continue }

            // Match SwiftTerm's row positioning (non-flipped: Y=0 at bottom)
            // Our `row` is 0-based visible row (getLine handles yDisp internally)
            // SwiftTerm positions: lineOffset = cellHeight * (absoluteRow - yDisp + 1)
            // Since row IS (absoluteRow - yDisp), this simplifies to:
            let lineOffset = cellHeight * CGFloat(row + 1)
            let lineOriginY = bounds.height - lineOffset

            // First: draw a single full-width opaque rect to completely cover
            // SwiftTerm's LTR rendering. No gaps, no sub-pixel bleed.
            let defaultBg = terminalView.nativeBackgroundColor ?? NSColor.black
            context.setFillColor(defaultBg.cgColor)
            context.fill(CGRect(
                x: 0,
                y: lineOriginY,
                width: bounds.width,
                height: cellHeight
            ))

            // Then: draw per-cell colored backgrounds on top (only non-default)
            for col in 0..<cols {
                let charData = line[col]
                let bgColor = nsColor(from: charData.attribute.bg, isForeground: false)
                if bgColor != defaultBg {
                    context.setFillColor(bgColor.cgColor)
                    context.fill(CGRect(
                        x: CGFloat(col) * cellWidth,
                        y: lineOriginY,
                        width: cellWidth + 1, // +1 to prevent sub-pixel gaps
                        height: cellHeight
                    ))
                }
            }

            // Build attributed string with per-character styling
            let attrString = NSMutableAttributedString(string: lineText)
            let fullRange = NSRange(location: 0, length: attrString.length)

            attrString.addAttribute(
                NSAttributedString.Key(kCTFontAttributeName as String),
                value: cascadeFont,
                range: fullRange
            )

            // Apply per-character foreground colors and styles
            var charIndex = 0
            for col in 0..<cols {
                guard charIndex < attrString.length else { break }
                let charData = line[col]
                let fgColor = nsColor(from: charData.attribute.fg, isForeground: true)
                let charRange = NSRange(location: charIndex, length: 1)

                attrString.addAttribute(.foregroundColor, value: fgColor, range: charRange)

                if charData.attribute.style.contains(.bold) {
                    if let boldFont = CTFontCreateCopyWithSymbolicTraits(cascadeFont, fontSize, nil, .boldTrait, .boldTrait) {
                        attrString.addAttribute(
                            NSAttributedString.Key(kCTFontAttributeName as String),
                            value: boldFont,
                            range: charRange
                        )
                    }
                }

                if charData.attribute.underlineStyle != .none {
                    attrString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: charRange)
                }

                charIndex += 1
            }

            // Set paragraph direction for RTL lines
            let paragraphDir = BiDiLineAnalyzer.paragraphDirection(lineText)
            if paragraphDir == .rtl {
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.baseWritingDirection = .rightToLeft
                paraStyle.alignment = .right
                attrString.addAttribute(.paragraphStyle, value: paraStyle, range: fullRange)
            }

            // Create CTLine — Core Text handles full UBA + Arabic shaping + reordering
            let ctLine = CTLineCreateWithAttributedString(attrString)

            // Draw text — non-flipped coordinates, baseline at lineOriginY + yOffset
            context.saveGState()
            context.textMatrix = .identity

            if paragraphDir == .rtl {
                let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
                let terminalWidth = CGFloat(cols) * cellWidth
                let xPos = terminalWidth - lineWidth
                context.textPosition = CGPoint(x: xPos, y: lineOriginY + yOffset)
            } else {
                context.textPosition = CGPoint(x: 0, y: lineOriginY + yOffset)
            }

            CTLineDraw(ctLine, context)
            context.restoreGState()

            // Draw visual cursor on the current RTL line
            let buffer = terminal.buffer
            if row == buffer.y && paragraphDir == .rtl {
                let logicalX = buffer.x
                let clampedIndex = min(logicalX, attrString.length)
                let visualOffset = CTLineGetOffsetForStringIndex(ctLine, clampedIndex, nil)

                let cursorX: CGFloat
                if paragraphDir == .rtl {
                    let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
                    let termWidth = CGFloat(cols) * cellWidth
                    cursorX = (termWidth - lineWidth) + CGFloat(visualOffset)
                } else {
                    cursorX = CGFloat(visualOffset)
                }

                // Draw cursor block
                let cursorColor = terminalView.caretColor
                context.setFillColor(cursorColor.withAlphaComponent(0.7).cgColor)
                context.fill(CGRect(
                    x: cursorX,
                    y: lineOriginY,
                    width: cellWidth,
                    height: cellHeight
                ))

                // Draw the character under cursor with inverted color
                if clampedIndex < attrString.length {
                    let charStr = (attrString.string as NSString).substring(with: NSRange(location: clampedIndex, length: 1))
                    let cursorAttr = NSAttributedString(
                        string: charStr,
                        attributes: [
                            NSAttributedString.Key(kCTFontAttributeName as String): cascadeFont,
                            .foregroundColor: terminalView.nativeBackgroundColor ?? NSColor.black
                        ]
                    )
                    let cursorLine = CTLineCreateWithAttributedString(cursorAttr)
                    context.saveGState()
                    context.textMatrix = .identity
                    context.textPosition = CGPoint(x: cursorX, y: lineOriginY + yOffset)
                    CTLineDraw(cursorLine, context)
                    context.restoreGState()
                }
            }
        }
    }

    // MARK: - Color Extraction

    private func nsColor(from attrColor: Attribute.Color, isForeground: Bool) -> NSColor {
        switch attrColor {
        case .trueColor(let r, let g, let b):
            return NSColor(
                red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0
            )
        case .ansi256(let code):
            return ansi256ToNSColor(code)
        case .defaultColor:
            return isForeground
                ? (terminalView?.nativeForegroundColor ?? NSColor(white: 0.92, alpha: 1))
                : (terminalView?.nativeBackgroundColor ?? NSColor.black)
        case .defaultInvertedColor:
            return isForeground
                ? (terminalView?.nativeBackgroundColor ?? NSColor.black)
                : (terminalView?.nativeForegroundColor ?? NSColor(white: 0.92, alpha: 1))
        }
    }

    private func ansi256ToNSColor(_ code: UInt8) -> NSColor {
        let basic16: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 0), (0.8, 0, 0), (0, 0.8, 0), (0.8, 0.8, 0),
            (0, 0, 0.8), (0.8, 0, 0.8), (0, 0.8, 0.8), (0.75, 0.75, 0.75),
            (0.5, 0.5, 0.5), (1, 0, 0), (0, 1, 0), (1, 1, 0),
            (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)
        ]
        if code < 16 {
            let c = basic16[Int(code)]
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        }
        if code < 232 {
            let idx = Int(code) - 16
            let b = CGFloat(idx % 6) / 5.0
            let g = CGFloat((idx / 6) % 6) / 5.0
            let r = CGFloat(idx / 36) / 5.0
            return NSColor(red: r, green: g, blue: b, alpha: 1)
        }
        let gray = CGFloat(Int(code) - 232) / 23.0
        return NSColor(white: gray, alpha: 1)
    }
}
