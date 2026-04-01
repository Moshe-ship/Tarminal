import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @AppStorage("shellPath") private var shellPath: String = "/bin/zsh"
    @AppStorage("cursorStyle") private var cursorStyle: String = "block"
    @AppStorage("scrollbackLines") private var scrollbackLines: Int = 10000
    @AppStorage("bidiMode") private var bidiMode: String = "auto"
    @AppStorage("opacity") private var opacity: Double = 1.0
    @AppStorage("optionAsMeta") private var optionAsMeta: Bool = false

    var body: some View {
        TabView {
            // Appearance
            Form {
                Section("Theme") {
                    Picker("Theme", selection: Binding(
                        get: { themeManager.currentTheme.name },
                        set: { name in
                            if let theme = themeManager.availableThemes.first(where: { $0.name == name }) {
                                themeManager.selectTheme(theme)
                            }
                        }
                    )) {
                        ForEach(themeManager.availableThemes) { theme in
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(theme.background.color)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                Text(theme.name)
                            }
                            .tag(theme.name)
                        }
                    }

                    Slider(value: $opacity, in: 0.5...1.0, step: 0.05) {
                        Text("Opacity: \(Int(opacity * 100))%")
                    }
                }

                Section("Font") {
                    HStack {
                        Text("Terminal Font")
                        Spacer()
                        Text(themeManager.currentTheme.fontName)
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }

                    HStack {
                        Text("Font Size")
                        Spacer()
                        Stepper("\(Int(themeManager.currentTheme.fontSize))pt",
                                value: Binding(
                                    get: { themeManager.currentTheme.fontSize },
                                    set: { newSize in
                                        var theme = themeManager.currentTheme
                                        theme.fontSize = newSize
                                        themeManager.selectTheme(theme)
                                    }
                                ),
                                in: 10...28, step: 1)
                    }
                }
            }
            .tabItem { Label("Appearance", systemImage: "paintbrush") }
            .padding()

            // Arabic / BiDi
            Form {
                Section("Arabic Text") {
                    Picker("Arabic Font", selection: Binding(
                        get: { themeManager.currentTheme.arabicFontName },
                        set: { newFont in
                            var theme = themeManager.currentTheme
                            theme.arabicFontName = newFont
                            themeManager.selectTheme(theme)
                        }
                    )) {
                        Text("Geeza Pro").tag("GeezaPro")
                        Text("SF Arabic").tag(".SFArabic-Regular")
                        Text("Baghdad").tag("Baghdad")
                        Text("Courier New Arabic").tag("CourierNewPSMT")
                    }

                    Picker("BiDi Mode", selection: $bidiMode) {
                        Text("Auto-detect (recommended)").tag("auto")
                        Text("Always LTR").tag("ltr")
                        Text("Always RTL").tag("rtl")
                    }
                }

                Section("Direction") {
                    Text("When BiDi mode is Auto, lines containing Arabic/Hebrew text will render right-to-left. Pure Latin lines stay left-to-right.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tabItem { Label("Arabic عربي", systemImage: "textformat") }
            .padding()

            // Terminal
            Form {
                Section("Shell") {
                    TextField("Shell Path", text: $shellPath)
                    Picker("Cursor Style", selection: $cursorStyle) {
                        Text("Block").tag("block")
                        Text("Underline").tag("underline")
                        Text("Bar").tag("bar")
                    }
                }

                Section("Scrollback") {
                    Stepper("Buffer: \(scrollbackLines) lines", value: $scrollbackLines, in: 1000...100000, step: 1000)
                }

                Section("Keyboard") {
                    Toggle("Option as Meta key", isOn: $optionAsMeta)
                }
            }
            .tabItem { Label("Terminal", systemImage: "terminal") }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}
