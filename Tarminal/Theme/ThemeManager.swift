import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: TerminalTheme
    @Published var availableThemes: [TerminalTheme]

    private let storageKey = "com.tarminal.currentTheme"

    init() {
        let builtIn = Self.builtInThemes()
        self.availableThemes = builtIn
        self.currentTheme = builtIn[0]
        loadSavedTheme()
    }

    func selectTheme(_ theme: TerminalTheme) {
        currentTheme = theme
        saveTheme()
    }

    private func saveTheme() {
        if let data = try? JSONEncoder().encode(currentTheme) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSavedTheme() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let theme = try? JSONDecoder().decode(TerminalTheme.self, from: data) {
            currentTheme = theme
        }
    }

    static func builtInThemes() -> [TerminalTheme] {
        [
            .defaultDark,
            TerminalTheme(
                id: UUID(),
                name: "Tarminal Light",
                background: CodableColor(r: 0.97, g: 0.97, b: 0.97),
                foreground: CodableColor(r: 0.1, g: 0.1, b: 0.1),
                cursor: CodableColor(r: 0.0, g: 0.6, b: 0.3),
                selection: CodableColor(r: 0.7, g: 0.85, b: 1.0),
                ansiColors: [
                    CodableColor(r: 0.0, g: 0.0, b: 0.0),
                    CodableColor(r: 0.8, g: 0.1, b: 0.1),
                    CodableColor(r: 0.1, g: 0.6, b: 0.1),
                    CodableColor(r: 0.6, g: 0.5, b: 0.0),
                    CodableColor(r: 0.1, g: 0.2, b: 0.7),
                    CodableColor(r: 0.6, g: 0.1, b: 0.6),
                    CodableColor(r: 0.0, g: 0.5, b: 0.5),
                    CodableColor(r: 0.9, g: 0.9, b: 0.9),
                    CodableColor(r: 0.3, g: 0.3, b: 0.3),
                    CodableColor(r: 1.0, g: 0.2, b: 0.2),
                    CodableColor(r: 0.2, g: 0.8, b: 0.2),
                    CodableColor(r: 0.8, g: 0.7, b: 0.0),
                    CodableColor(r: 0.2, g: 0.4, b: 1.0),
                    CodableColor(r: 0.8, g: 0.2, b: 0.8),
                    CodableColor(r: 0.0, g: 0.7, b: 0.7),
                    CodableColor(r: 1.0, g: 1.0, b: 1.0),
                ],
                fontName: "SFMono-Regular",
                fontSize: 14,
                arabicFontName: "GeezaPro"
            ),
            TerminalTheme(
                id: UUID(),
                name: "Dracula",
                background: CodableColor(r: 0.16, g: 0.16, b: 0.21),
                foreground: CodableColor(r: 0.97, g: 0.97, b: 0.95),
                cursor: CodableColor(r: 0.97, g: 0.97, b: 0.95),
                selection: CodableColor(r: 0.27, g: 0.28, b: 0.35),
                ansiColors: [
                    CodableColor(r: 0.13, g: 0.14, b: 0.18),
                    CodableColor(r: 1.0, g: 0.33, b: 0.38),
                    CodableColor(r: 0.31, g: 0.98, b: 0.48),
                    CodableColor(r: 0.94, g: 0.98, b: 0.55),
                    CodableColor(r: 0.74, g: 0.58, b: 0.98),
                    CodableColor(r: 1.0, g: 0.47, b: 0.66),
                    CodableColor(r: 0.55, g: 0.91, b: 0.99),
                    CodableColor(r: 0.97, g: 0.97, b: 0.95),
                    CodableColor(r: 0.4, g: 0.42, b: 0.53),
                    CodableColor(r: 1.0, g: 0.33, b: 0.38),
                    CodableColor(r: 0.31, g: 0.98, b: 0.48),
                    CodableColor(r: 0.94, g: 0.98, b: 0.55),
                    CodableColor(r: 0.74, g: 0.58, b: 0.98),
                    CodableColor(r: 1.0, g: 0.47, b: 0.66),
                    CodableColor(r: 0.55, g: 0.91, b: 0.99),
                    CodableColor(r: 0.97, g: 0.97, b: 0.95),
                ],
                fontName: "SFMono-Regular",
                fontSize: 14,
                arabicFontName: "GeezaPro"
            ),
            TerminalTheme(
                id: UUID(),
                name: "Nord",
                background: CodableColor(r: 0.18, g: 0.20, b: 0.25),
                foreground: CodableColor(r: 0.85, g: 0.87, b: 0.91),
                cursor: CodableColor(r: 0.85, g: 0.87, b: 0.91),
                selection: CodableColor(r: 0.26, g: 0.30, b: 0.37),
                ansiColors: [
                    CodableColor(r: 0.23, g: 0.26, b: 0.32),
                    CodableColor(r: 0.75, g: 0.38, b: 0.42),
                    CodableColor(r: 0.64, g: 0.75, b: 0.55),
                    CodableColor(r: 0.92, g: 0.80, b: 0.55),
                    CodableColor(r: 0.51, g: 0.63, b: 0.76),
                    CodableColor(r: 0.71, g: 0.56, b: 0.68),
                    CodableColor(r: 0.54, g: 0.73, b: 0.73),
                    CodableColor(r: 0.91, g: 0.93, b: 0.94),
                    CodableColor(r: 0.30, g: 0.34, b: 0.42),
                    CodableColor(r: 0.75, g: 0.38, b: 0.42),
                    CodableColor(r: 0.64, g: 0.75, b: 0.55),
                    CodableColor(r: 0.92, g: 0.80, b: 0.55),
                    CodableColor(r: 0.51, g: 0.63, b: 0.76),
                    CodableColor(r: 0.71, g: 0.56, b: 0.68),
                    CodableColor(r: 0.54, g: 0.73, b: 0.73),
                    CodableColor(r: 0.91, g: 0.93, b: 0.94),
                ],
                fontName: "SFMono-Regular",
                fontSize: 14,
                arabicFontName: "GeezaPro"
            ),
            TerminalTheme(
                id: UUID(),
                name: "سراب (Sarab)",
                background: CodableColor(r: 0.06, g: 0.05, b: 0.08),
                foreground: CodableColor(r: 0.88, g: 0.85, b: 0.78),
                cursor: CodableColor(r: 0.82, g: 0.62, b: 0.2),
                selection: CodableColor(r: 0.25, g: 0.2, b: 0.12),
                ansiColors: [
                    CodableColor(r: 0.1, g: 0.08, b: 0.06),
                    CodableColor(r: 0.85, g: 0.3, b: 0.25),
                    CodableColor(r: 0.55, g: 0.75, b: 0.35),
                    CodableColor(r: 0.82, g: 0.62, b: 0.2),
                    CodableColor(r: 0.35, g: 0.5, b: 0.7),
                    CodableColor(r: 0.65, g: 0.4, b: 0.6),
                    CodableColor(r: 0.4, g: 0.65, b: 0.6),
                    CodableColor(r: 0.88, g: 0.85, b: 0.78),
                    CodableColor(r: 0.35, g: 0.3, b: 0.25),
                    CodableColor(r: 0.95, g: 0.4, b: 0.35),
                    CodableColor(r: 0.65, g: 0.85, b: 0.45),
                    CodableColor(r: 0.92, g: 0.72, b: 0.3),
                    CodableColor(r: 0.45, g: 0.6, b: 0.8),
                    CodableColor(r: 0.75, g: 0.5, b: 0.7),
                    CodableColor(r: 0.5, g: 0.75, b: 0.7),
                    CodableColor(r: 0.95, g: 0.92, b: 0.85),
                ],
                fontName: "SFMono-Regular",
                fontSize: 14,
                arabicFontName: "GeezaPro"
            ),
        ]
    }
}
