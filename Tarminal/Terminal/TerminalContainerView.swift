import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab
    @ObservedObject var themeManager = ThemeManager.shared
    @AppStorage("opacity") private var opacity: Double = 1.0

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizesSubviews = true

        // --- Vibrancy layer (frosted glass, behind everything) ---
        let vibrancy = NSVisualEffectView(frame: container.bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.blendingMode = .behindWindow
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.isHidden = (opacity >= 1.0)
        container.addSubview(vibrancy)
        context.coordinator.vibrancyView = vibrancy

        // --- Terminal view (above vibrancy) ---
        let terminalView = LocalProcessTerminalView(frame: container.bounds)
        terminalView.autoresizingMask = [.width, .height]

        // Apply theme with transparency
        applyTheme(to: terminalView)

        // Enable clickable URLs:
        // linkReporting defaults to .implicit (OSC 8 + auto-detected URLs) — already set.
        // Set linkHighlightMode to .hover: URLs underline on hover, click to open.
        // For Cmd+click like iTerm2, change to .hoverWithModifier.
        terminalView.linkHighlightMode = .hover

        // Set process delegate only. Do NOT override terminalDelegate —
        // LocalProcessTerminalView sets itself as terminalDelegate in setup()
        // and uses it to bridge pty I/O. Overriding it breaks keyboard input.
        terminalView.processDelegate = context.coordinator

        container.addSubview(terminalView)

        // --- BiDi overlay (disabled until alignment is pixel-perfect) ---
        // SwiftTerm already renders Arabic with connected letters via Core Text.
        // The overlay adds duplicate text until row alignment is fixed.
        // let overlay = BiDiOverlayView(frame: container.bounds)
        // overlay.autoresizingMask = [.width, .height]
        // overlay.terminalView = terminalView
        // container.addSubview(overlay)

        // Store references
        context.coordinator.terminalView = terminalView

        // Start shell (validated)
        DispatchQueue.main.async {
            let allowedShells = ["/bin/zsh", "/bin/bash", "/bin/sh",
                                 "/usr/local/bin/zsh", "/usr/local/bin/bash",
                                 "/usr/local/bin/fish", "/opt/homebrew/bin/zsh",
                                 "/opt/homebrew/bin/bash", "/opt/homebrew/bin/fish"]

            let requested = UserDefaults.standard.string(forKey: "shellPath")
                ?? ProcessInfo.processInfo.environment["SHELL"]
                ?? "/bin/zsh"

            // Validate: must be absolute path, must exist, must be executable
            let shell: String
            if requested.hasPrefix("/"),
               FileManager.default.isExecutableFile(atPath: requested),
               allowedShells.contains(requested) || FileManager.default.fileExists(atPath: requested) {
                shell = requested
            } else {
                shell = "/bin/zsh" // Safe fallback
            }

            terminalView.startProcess(
                executable: shell,
                args: ["--login"],
                environment: nil,
                execName: nil
            )
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let tv = context.coordinator.terminalView {
            applyTheme(to: tv)
            tv.window?.makeFirstResponder(tv)
        }

        // Show/hide vibrancy based on opacity setting
        if let vibrancy = context.coordinator.vibrancyView {
            vibrancy.isHidden = (opacity >= 1.0)
        }

        context.coordinator.overlayView?.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    private func applyTheme(to terminalView: LocalProcessTerminalView) {
        let theme = themeManager.currentTheme

        // When opacity < 1.0, use a translucent background so vibrancy bleeds through.
        // This keeps text fully opaque (unlike setting alphaValue on the whole view).
        let bgAlpha = CGFloat(opacity)
        let bgColor = theme.background.nsColor.withAlphaComponent(bgAlpha)
        terminalView.nativeBackgroundColor = bgColor
        terminalView.nativeForegroundColor = theme.foreground.nsColor

        // Ensure the layer respects transparency
        terminalView.layer?.isOpaque = (opacity >= 1.0)
        terminalView.layer?.backgroundColor = bgColor.cgColor

        let font = NSFont(name: theme.fontName, size: theme.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        terminalView.font = font

        // Cursor and selection colors
        terminalView.caretColor = theme.cursor.nsColor
        terminalView.selectedTextBackgroundColor = theme.selection.nsColor

        // Apply ANSI colors
        if theme.ansiColors.count == 16 {
            let colors = theme.ansiColors.map {
                SwiftTerm.Color(
                    red: UInt16($0.r * 65535),
                    green: UInt16($0.g * 65535),
                    blue: UInt16($0.b * 65535)
                )
            }
            terminalView.installColors(colors)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab
        var terminalView: LocalProcessTerminalView?
        var overlayView: BiDiOverlayView?
        var vibrancyView: NSVisualEffectView?
        private var refreshTimer: Timer?

        init(tab: TerminalTab) {
            self.tab = tab
            super.init()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.overlayView?.needsDisplay = true
            }
        }

        deinit { refreshTimer?.invalidate() }

        // MARK: LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async {
                self.tab.title = title.isEmpty ? "zsh" : title
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async { self.tab.workingDirectory = dir }
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { self.tab.isTerminated = true }
        }

        // URL clicking: LocalProcessTerminalView conforms to TerminalViewDelegate and
        // inherits the default requestOpenLink implementation which calls
        // NSWorkspace.shared.open(url). No extra code needed here.
    }
}
