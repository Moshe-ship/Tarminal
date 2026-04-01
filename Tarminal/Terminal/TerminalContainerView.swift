import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab
    @ObservedObject var themeManager = ThemeManager.shared
    @AppStorage("opacity") var opacity: Double = 1.0

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizesSubviews = true

        // Vibrancy layer (frosted glass effect)
        let vibrancyView = NSVisualEffectView(frame: container.bounds)
        vibrancyView.autoresizingMask = [.width, .height]
        vibrancyView.material = .hudWindow
        vibrancyView.blendingMode = .behindWindow
        vibrancyView.state = .active
        vibrancyView.alphaValue = opacity < 1.0 ? 1.0 : 0.0 // Only show when transparent
        container.addSubview(vibrancyView)
        context.coordinator.vibrancyView = vibrancyView

        // Terminal view
        let terminalView = LocalProcessTerminalView(frame: container.bounds)
        terminalView.autoresizingMask = [.width, .height]
        applyTheme(to: terminalView)

        // Set both delegates
        terminalView.processDelegate = context.coordinator
        terminalView.terminalDelegate = context.coordinator

        container.addSubview(terminalView)

        // BiDi overlay
        let overlay = BiDiOverlayView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.terminalView = terminalView
        container.addSubview(overlay)

        // Store references
        context.coordinator.terminalView = terminalView
        context.coordinator.overlayView = overlay

        // Start shell
        DispatchQueue.main.async {
            let shell = UserDefaults.standard.string(forKey: "shellPath")
                ?? ProcessInfo.processInfo.environment["SHELL"]
                ?? "/bin/zsh"

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

            // Update transparency
            if let vibrancy = context.coordinator.vibrancyView {
                if opacity < 1.0 {
                    vibrancy.alphaValue = 1.0
                    tv.alphaValue = CGFloat(opacity)
                } else {
                    vibrancy.alphaValue = 0.0
                    tv.alphaValue = 1.0
                }
            }
        }
        context.coordinator.overlayView?.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    private func applyTheme(to terminalView: LocalProcessTerminalView) {
        let theme = themeManager.currentTheme
        terminalView.nativeBackgroundColor = theme.background.nsColor
        terminalView.nativeForegroundColor = theme.foreground.nsColor

        let font = NSFont(name: theme.fontName, size: theme.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        terminalView.font = font

        // Apply cursor color
        terminalView.caretColor = theme.cursor.nsColor

        // Apply selection color
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

    class Coordinator: NSObject, TerminalViewDelegate, LocalProcessTerminalViewDelegate {
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

        // MARK: TerminalViewDelegate

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: TerminalView, title: String) {
            DispatchQueue.main.async {
                self.tab.title = title.isEmpty ? "zsh" : title
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async { self.tab.workingDirectory = dir }
            }
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            // Data is sent by SwiftTerm internally for LocalProcess
        }

        func scrolled(source: TerminalView, position: Double) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            // Open URLs in default browser
            if let url = URL(string: link) {
                NSWorkspace.shared.open(url)
            }
        }

        func bell(source: TerminalView) {
            NSSound.beep()
        }

        func clipboardCopy(source: TerminalView, content: Data) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(content, forType: .string)
        }

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
            overlayView?.needsDisplay = true
        }

        // MARK: LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async {
                self.tab.title = title.isEmpty ? "zsh" : title
            }
        }

        func hostCurrentDirectoryUpdate(source: LocalProcessTerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async { self.tab.workingDirectory = dir }
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { self.tab.isTerminated = true }
        }
    }
}
