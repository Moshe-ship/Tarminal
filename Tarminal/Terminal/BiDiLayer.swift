import AppKit
import SwiftTerm
import CoreText
import QuartzCore

/// CALayer that renders RTL lines on top of SwiftTerm's CoreGraphics output.
/// Added as a sublayer of the terminal view's layer — draws after terminal content.
/// No separate NSView, no z-order issues, same coordinate space.
class BiDiLayer: CALayer {

    weak var terminalView: TarminalTerminalView?

    override func draw(in ctx: CGContext) {
        guard let terminalView = terminalView else { return }

        let bidiMode = terminalView.bidiMode
        // BiDi only renders when explicitly enabled ("auto" or "rtl")
        // Default is "ltr" = standard terminal behavior, zero interference
        if bidiMode == "ltr" { return }

        let terminal = terminalView.getTerminal()

        // Skip alternate screen buffer (vim, less, man, etc.)
        if terminal.isCurrentBufferAlternate { return }

        let cols = terminal.cols
        let rows = terminal.rows

        // Match SwiftTerm's cell dimensions exactly
        let termFont = terminalView.font
        let fontSize = termFont.pointSize
        let scale = contentsScale

        let nsGlyph = termFont.glyph(withName: "W")
        let rawCellWidth = termFont.advancement(forGlyph: nsGlyph).width
        let cellWidth = ceil(rawCellWidth * scale) / scale

        let ctFont = CTFontCreateWithName(termFont.fontName as CFString, fontSize, nil)
        let rawCellHeight = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont)
        let cellHeight = ceil(rawCellHeight * scale) / scale

        // Build cascade font
        let arabicFontName = terminalView.arabicFontName
        let arabicDesc = CTFontDescriptorCreateWithNameAndSize(arabicFontName as CFString, fontSize)
        let cascadeAttrs: [CFString: Any] = [kCTFontCascadeListAttribute: [arabicDesc]]
        let mergedDesc = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(ctFont), cascadeAttrs as CFDictionary
        )
        let cascadeFont = CTFontCreateWithFontDescriptor(mergedDesc, fontSize, nil)

        let lineDescent = CTFontGetDescent(ctFont)
        let lineLeading = CTFontGetLeading(ctFont)
        let yOffset = ceil(lineDescent + lineLeading)

        let defaultBg = terminalView.nativeBackgroundColor ?? NSColor.black

        for row in 0..<rows {
            guard let line = terminal.getLine(row: row) else { continue }
            let lineText = line.translateToString()

            let needsRTL: Bool
            if bidiMode == "rtl" {
                needsRTL = !lineText.trimmingCharacters(in: .whitespaces).isEmpty
            } else {
                needsRTL = BiDiLineAnalyzer.containsRTL(lineText)
            }
            guard needsRTL else { continue }

            // SwiftTerm's positioning (non-flipped, Y=0 at bottom)
            let lineOffset = cellHeight * CGFloat(row + 1)
            let lineOriginY = bounds.height - lineOffset

            // 1. Opaque background to cover SwiftTerm
            ctx.setFillColor(defaultBg.cgColor)
            ctx.fill(CGRect(x: 0, y: lineOriginY, width: bounds.width, height: cellHeight))

            // 2. Per-cell colored backgrounds
            for col in 0..<cols {
                let charData = line[col]
                let bgColor = nsColorFromAttr(charData.attribute.bg, isFg: false, tv: terminalView)
                if bgColor != defaultBg {
                    ctx.setFillColor(bgColor.cgColor)
                    ctx.fill(CGRect(x: CGFloat(col) * cellWidth, y: lineOriginY, width: cellWidth + 1, height: cellHeight))
                }
            }

            // 3. Build attributed string
            let attrString = NSMutableAttributedString(string: lineText)
            let fullRange = NSRange(location: 0, length: attrString.length)
            attrString.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: cascadeFont, range: fullRange)

            var charIndex = 0
            for col in 0..<cols {
                guard charIndex < attrString.length else { break }
                let charData = line[col]
                let fgColor = nsColorFromAttr(charData.attribute.fg, isFg: true, tv: terminalView)
                let charRange = NSRange(location: charIndex, length: 1)
                attrString.addAttribute(.foregroundColor, value: fgColor, range: charRange)

                if charData.attribute.style.contains(.bold) {
                    if let bf = CTFontCreateCopyWithSymbolicTraits(cascadeFont, fontSize, nil, .boldTrait, .boldTrait) {
                        attrString.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: bf, range: charRange)
                    }
                }
                if charData.attribute.underlineStyle != .none {
                    attrString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: charRange)
                }
                charIndex += 1
            }

            // 4. Paragraph direction
            let paragraphDir = BiDiLineAnalyzer.paragraphDirection(lineText)
            if paragraphDir == .rtl {
                let ps = NSMutableParagraphStyle()
                ps.baseWritingDirection = .rightToLeft
                ps.alignment = .right
                attrString.addAttribute(.paragraphStyle, value: ps, range: fullRange)
            }

            // 5. Draw
            let ctLine = CTLineCreateWithAttributedString(attrString)
            ctx.saveGState()
            ctx.textMatrix = .identity

            if paragraphDir == .rtl {
                let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
                let termWidth = CGFloat(cols) * cellWidth
                ctx.textPosition = CGPoint(x: termWidth - lineWidth, y: lineOriginY + yOffset)
            } else {
                ctx.textPosition = CGPoint(x: 0, y: lineOriginY + yOffset)
            }
            CTLineDraw(ctLine, ctx)
            ctx.restoreGState()

            // 6. Cursor on current RTL line
            let buffer = terminal.buffer
            if row == buffer.y && paragraphDir == .rtl {
                let logicalX = buffer.x
                let clampedIndex = min(logicalX, attrString.length)
                let visualOffset = CTLineGetOffsetForStringIndex(ctLine, clampedIndex, nil)
                let lw = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
                let tw = CGFloat(cols) * cellWidth
                let cursorX = (tw - lw) + CGFloat(visualOffset)
                ctx.setFillColor(terminalView.caretColor.withAlphaComponent(0.7).cgColor)
                ctx.fill(CGRect(x: cursorX, y: lineOriginY, width: cellWidth, height: cellHeight))
            }
        }
    }

    // MARK: - Color helpers

    private func nsColorFromAttr(_ attrColor: Attribute.Color, isFg: Bool, tv: TarminalTerminalView) -> NSColor {
        switch attrColor {
        case .trueColor(let r, let g, let b):
            return NSColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
        case .ansi256(let code):
            return ansi256Color(code)
        case .defaultColor:
            return isFg ? (tv.nativeForegroundColor ?? .white) : (tv.nativeBackgroundColor ?? .black)
        case .defaultInvertedColor:
            return isFg ? (tv.nativeBackgroundColor ?? .black) : (tv.nativeForegroundColor ?? .white)
        }
    }

    private func ansi256Color(_ code: UInt8) -> NSColor {
        let b16: [(CGFloat,CGFloat,CGFloat)] = [
            (0,0,0),(0.8,0,0),(0,0.8,0),(0.8,0.8,0),(0,0,0.8),(0.8,0,0.8),(0,0.8,0.8),(0.75,0.75,0.75),
            (0.5,0.5,0.5),(1,0,0),(0,1,0),(1,1,0),(0,0,1),(1,0,1),(0,1,1),(1,1,1)
        ]
        if code < 16 { let c = b16[Int(code)]; return NSColor(red:c.0,green:c.1,blue:c.2,alpha:1) }
        if code < 232 { let i=Int(code)-16; return NSColor(red:CGFloat(i/36)/5,green:CGFloat((i/6)%6)/5,blue:CGFloat(i%6)/5,alpha:1) }
        return NSColor(white: CGFloat(Int(code)-232)/23, alpha: 1)
    }
}
