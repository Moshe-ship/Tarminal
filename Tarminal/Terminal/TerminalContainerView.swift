import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab
    @ObservedObject var themeManager = ThemeManager.shared

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizesSubviews = true

        let terminalView = LocalProcessTerminalView(frame: container.bounds)
        terminalView.autoresizingMask = [.width, .height]

        // Apply theme
        applyTheme(to: terminalView)

        // Set process delegate
        terminalView.processDelegate = context.coordinator

        // Add terminal to container
        container.addSubview(terminalView)

        // Create BiDi overlay
        let overlay = BiDiOverlayView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.terminalView = terminalView
        container.addSubview(overlay)

        // Store references
        context.coordinator.terminalView = terminalView
        context.coordinator.overlayView = overlay

        // Start shell
        DispatchQueue.main.async {
            let shell = UserDefaults.standard.string(forKey: "shellPath") ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
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
        // Re-apply theme if changed
        if let tv = context.coordinator.terminalView {
            applyTheme(to: tv)
            tv.window?.makeFirstResponder(tv)
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

        // Apply ANSI colors
        if theme.ansiColors.count == 16 {
            let colors = theme.ansiColors.map { SwiftTerm.Color(red: UInt16($0.r * 65535), green: UInt16($0.g * 65535), blue: UInt16($0.b * 65535)) }
            terminalView.installColors(colors)
        }
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab
        var terminalView: LocalProcessTerminalView?
        var overlayView: BiDiOverlayView?
        private var refreshTimer: Timer?

        init(tab: TerminalTab) {
            self.tab = tab
            super.init()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.overlayView?.needsDisplay = true
            }
        }

        deinit { refreshTimer?.invalidate() }

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
    }
}
