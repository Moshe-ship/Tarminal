import SwiftUI

struct TerminalTheme: Identifiable, Codable {
    let id: UUID
    var name: String
    var background: CodableColor
    var foreground: CodableColor
    var cursor: CodableColor
    var selection: CodableColor
    var ansiColors: [CodableColor] // 16 ANSI colors
    var fontName: String
    var fontSize: CGFloat

    static let defaultDark = TerminalTheme(
        id: UUID(),
        name: "Tarminal Dark",
        background: CodableColor(r: 0.04, g: 0.04, b: 0.04),
        foreground: CodableColor(r: 0.92, g: 0.92, b: 0.92),
        cursor: CodableColor(r: 0.0, g: 1.0, b: 0.25),
        selection: CodableColor(r: 0.2, g: 0.3, b: 0.5),
        ansiColors: [
            // Normal: black, red, green, yellow, blue, magenta, cyan, white
            CodableColor(r: 0.1, g: 0.1, b: 0.1),
            CodableColor(r: 0.9, g: 0.3, b: 0.3),
            CodableColor(r: 0.3, g: 0.9, b: 0.3),
            CodableColor(r: 0.9, g: 0.8, b: 0.3),
            CodableColor(r: 0.4, g: 0.5, b: 0.9),
            CodableColor(r: 0.8, g: 0.4, b: 0.8),
            CodableColor(r: 0.3, g: 0.8, b: 0.8),
            CodableColor(r: 0.85, g: 0.85, b: 0.85),
            // Bright: black, red, green, yellow, blue, magenta, cyan, white
            CodableColor(r: 0.4, g: 0.4, b: 0.4),
            CodableColor(r: 1.0, g: 0.4, b: 0.4),
            CodableColor(r: 0.4, g: 1.0, b: 0.4),
            CodableColor(r: 1.0, g: 0.9, b: 0.4),
            CodableColor(r: 0.5, g: 0.6, b: 1.0),
            CodableColor(r: 0.9, g: 0.5, b: 0.9),
            CodableColor(r: 0.4, g: 0.9, b: 0.9),
            CodableColor(r: 1.0, g: 1.0, b: 1.0),
        ],
        fontName: "SFMono-Regular",
        fontSize: 14
    )
}

struct CodableColor: Codable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1.0

    var nsColor: NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }
}
