import SwiftUI

struct SettingsView: View {
    @AppStorage("fontSize") private var fontSize: Double = 14
    @AppStorage("fontName") private var fontName: String = "SFMono-Regular"
    @AppStorage("arabicFontName") private var arabicFontName: String = "GeezaPro"
    @AppStorage("bidiMode") private var bidiMode: String = "auto"
    @AppStorage("shellPath") private var shellPath: String = "/bin/zsh"
    @AppStorage("cursorStyle") private var cursorStyle: String = "block"

    var body: some View {
        TabView {
            // Appearance
            Form {
                Section("Font") {
                    HStack {
                        Text("Terminal Font")
                        Spacer()
                        Text(fontName)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontSize, in: 10...24, step: 1) {
                        Text("Size: \(Int(fontSize))pt")
                    }
                }

                Section("Arabic") {
                    Picker("Arabic Font", selection: $arabicFontName) {
                        Text("Geeza Pro").tag("GeezaPro")
                        Text("SF Arabic").tag(".SFArabic-Regular")
                        Text("Baghdad").tag("Baghdad")
                    }

                    Picker("BiDi Mode", selection: $bidiMode) {
                        Text("Auto-detect").tag("auto")
                        Text("Always LTR").tag("ltr")
                        Text("Always RTL").tag("rtl")
                    }
                }
            }
            .tabItem { Label("Appearance", systemImage: "paintbrush") }

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
            }
            .tabItem { Label("Terminal", systemImage: "terminal") }
        }
        .frame(width: 450, height: 300)
        .padding()
    }
}
