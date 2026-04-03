import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager = ThemeManager.shared

    // Appearance
    @AppStorage("opacity") private var opacity: Double = 1.0

    // Terminal
    @AppStorage("shellPath") private var shellPath: String = "/bin/zsh"
    @AppStorage("cursorStyle") private var cursorStyle: String = "block"
    @AppStorage("cursorBlink") private var cursorBlink: Bool = false
    @AppStorage("scrollbackLines") private var scrollbackLines: Int = 10000
    @AppStorage("optionAsMeta") private var optionAsMeta: Bool = false

    // Arabic / BiDi
    @AppStorage("bidiMode") private var bidiMode: String = "auto"

    // System
    @AppStorage("confirmClose") private var confirmClose: Bool = true
    @AppStorage("bellSound") private var bellSound: Bool = true
    @AppStorage("bellBounce") private var bellBounce: Bool = false
    @AppStorage("newTabWorkingDir") private var newTabWorkingDir: String = "home"
    @AppStorage("titleBarStyle") private var titleBarStyle: String = "directory"

    var body: some View {
        TabView {
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag("appearance")

            arabicTab
                .tabItem { Label("Arabic عربي", systemImage: "textformat") }
                .tag("arabic")

            terminalTab
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .tag("terminal")

            keyboardTab
                .tabItem { Label("Keyboard", systemImage: "keyboard") }
                .tag("keyboard")

            systemTab
                .tabItem { Label("System", systemImage: "gearshape") }
                .tag("system")
        }
        .frame(width: 540, height: 460)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
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
                        HStack(spacing: 8) {
                            // Color preview swatches
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.background.color)
                                    .frame(width: 12, height: 12)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.foreground.color)
                                    .frame(width: 12, height: 12)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.cursor.color)
                                    .frame(width: 12, height: 12)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            Text(theme.name)
                        }
                        .tag(theme.name)
                    }
                }

                // Theme preview
                HStack(spacing: 0) {
                    ForEach(0..<8) { i in
                        if i < themeManager.currentTheme.ansiColors.count {
                            Rectangle()
                                .fill(themeManager.currentTheme.ansiColors[i].color)
                                .frame(height: 8)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.vertical, 2)
            }

            Section("Window") {
                Slider(value: $opacity, in: 0.3...1.0, step: 0.05) {
                    Text("Opacity: \(Int(opacity * 100))%")
                }

                Picker("Title Bar Shows", selection: $titleBarStyle) {
                    Text("Current Directory").tag("directory")
                    Text("Shell Name").tag("shell")
                    Text("Nothing").tag("none")
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
        .padding()
    }

    // MARK: - Arabic Tab

    private var arabicTab: some View {
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
                    Text("KufiStandardGK").tag("KufiStandardGK")
                    Text("Noto Naskh Arabic").tag("NotoNaskhArabic")
                }

                Picker("BiDi Mode", selection: $bidiMode) {
                    Text("Auto-detect (recommended)").tag("auto")
                    Text("Always LTR").tag("ltr")
                    Text("Always RTL").tag("rtl")
                }
            }

            Section("Direction Behavior") {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("**Auto**: Lines with Arabic/Hebrew render right-to-left. Pure Latin lines stay left-to-right.")
                    } icon: {
                        Image(systemName: "text.alignright")
                            .foregroundColor(.green)
                    }

                    Label {
                        Text("**Always RTL**: All non-empty lines render right-to-left regardless of content.")
                    } icon: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.orange)
                    }

                    Label {
                        Text("**Always LTR**: BiDi overlay disabled. Standard terminal behavior.")
                    } icon: {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("مرحبا بالعالم — Hello World")
                        .font(.system(.body, design: .monospaced))
                    Text("echo \"ترمنال يعمل بشكل صحيح\"")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(themeManager.currentTheme.background.color)
                .foregroundColor(themeManager.currentTheme.foreground.color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
    }

    // MARK: - Terminal Tab

    private var terminalTab: some View {
        Form {
            Section("Shell") {
                TextField("Shell Path", text: $shellPath)
                    .font(.system(.body, design: .monospaced))

                Text("Common: /bin/zsh, /bin/bash, /opt/homebrew/bin/fish")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Cursor") {
                Picker("Cursor Style", selection: $cursorStyle) {
                    HStack {
                        Rectangle().frame(width: 8, height: 14)
                        Text("Block")
                    }.tag("block")
                    HStack {
                        Rectangle().frame(width: 8, height: 2)
                        Text("Underline")
                    }.tag("underline")
                    HStack {
                        Rectangle().frame(width: 2, height: 14)
                        Text("Bar")
                    }.tag("bar")
                }

                Toggle("Cursor Blink", isOn: $cursorBlink)
            }

            Section("Scrollback") {
                Stepper("Buffer: \(scrollbackLines) lines",
                        value: $scrollbackLines, in: 500...100000, step: 500)

                Text("Higher values use more memory. 10,000 is a good default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("New Tab") {
                Picker("Working Directory", selection: $newTabWorkingDir) {
                    Text("Home Directory").tag("home")
                    Text("Same as Current Tab").tag("current")
                    Text("Root /").tag("root")
                }
            }

        }
        .padding()
    }

    // MARK: - Keyboard Tab

    private var keyboardTab: some View {
        Form {
            Section("Key Behavior") {
                Toggle("Option as Meta Key", isOn: $optionAsMeta)
                Text("When enabled, Option sends ESC prefix (like Alt in Linux terminals). When disabled, Option types special characters (e.g., Option+3 = #).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Shortcuts") {
                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow("New Tab", "Cmd + T")
                    shortcutRow("Close Tab", "Cmd + W")
                    shortcutRow("Next Tab", "Cmd + Shift + ]")
                    shortcutRow("Previous Tab", "Cmd + Shift + [")
                    shortcutRow("Tab 1-9", "Cmd + 1-9")
                    Divider()
                    shortcutRow("Find", "Cmd + F")
                    shortcutRow("Find Next", "Cmd + G")
                    shortcutRow("Find Previous", "Cmd + Shift + G")
                    Divider()
                    shortcutRow("Copy", "Cmd + C")
                    shortcutRow("Paste", "Cmd + V")
                    shortcutRow("Clear Buffer", "Cmd + K")
                    shortcutRow("Settings", "Cmd + ,")
                }
            }
        }
        .padding()
    }

    // MARK: - System Tab

    private var systemTab: some View {
        Form {
            Section("Notifications") {
                Toggle("Bell Sound", isOn: $bellSound)
                Text("Play system beep on terminal bell character (\\a)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Bounce Dock Icon on Bell", isOn: $bellBounce)
                Text("Bounce the dock icon when bell fires and Tarminal is in background")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Toggle("Confirm Before Closing", isOn: $confirmClose)
                Text("Ask for confirmation when closing a tab with a running process")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About") {
                HStack {
                    Text("Tarminal ترمنال")
                        .font(.headline)
                    Spacer()
                    Text("Phase 3")
                        .foregroundColor(.secondary)
                }
                Text("The first macOS terminal with native Arabic RTL support.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func shortcutRow(_ action: String, _ keys: String) -> some View {
        HStack {
            Text(action)
                .frame(width: 140, alignment: .leading)
            Spacer()
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
