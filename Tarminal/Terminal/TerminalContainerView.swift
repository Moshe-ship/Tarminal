import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab
    @ObservedObject var themeManager = ThemeManager.shared
    @AppStorage("opacity") private var opacity: Double = 1.0
    @AppStorage("cursorStyle") private var cursorStyle: String = "block"
    @AppStorage("cursorBlink") private var cursorBlink: Bool = false
    @AppStorage("optionAsMeta") private var optionAsMeta: Bool = false
    @AppStorage("bidiMode") private var bidiMode: String = "auto"
    @AppStorage("bellSound") private var bellSound: Bool = true
    @AppStorage("bellBounce") private var bellBounce: Bool = false
    @AppStorage("titleBarStyle") private var titleBarStyle: String = "directory"
    @AppStorage("scrollbackLines") private var scrollbackLines: Int = 10000
    @AppStorage("useMetalRenderer") private var useMetalRenderer: Bool = true

    func makeNSView(context: Context) -> NSView {
        let container = TerminalDropView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizesSubviews = true

        // --- Vibrancy layer ---
        let vibrancy = NSVisualEffectView(frame: container.bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.blendingMode = .behindWindow
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.isHidden = (opacity >= 1.0)
        container.addSubview(vibrancy)
        context.coordinator.vibrancyView = vibrancy

        // --- Terminal view (custom subclass for bell control) ---
        let terminalView = TarminalTerminalView(frame: container.bounds)
        terminalView.autoresizingMask = [.width, .height]

        // Bell settings
        terminalView.bellSoundEnabled = bellSound
        terminalView.bellBounceEnabled = bellBounce
        terminalView.arabicFontName = themeManager.currentTheme.arabicFontName
        terminalView.bidiMode = bidiMode

        // Apply theme + settings
        applyTheme(to: terminalView)
        applyCursorStyle(to: terminalView)
        terminalView.optionAsMetaKey = optionAsMeta

        // Scrollback — use the proper API that resizes the live buffer
        terminalView.changeScrollback(scrollbackLines)

        // Clickable URLs
        terminalView.linkHighlightMode = .hover

        // Metal GPU rendering — Apple Silicon native
        if useMetalRenderer {
            terminalView.enableMetal()
        }

        // Process delegate
        terminalView.processDelegate = context.coordinator
        context.coordinator.titleBarStyle = titleBarStyle

        container.addSubview(terminalView)

        // --- BiDi overlay (must be topmost to cover Metal/CoreGraphics rendering) ---
        let overlay = BiDiOverlayView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.zPosition = 100 // Force above Metal MTKView
        overlay.terminalView = terminalView
        overlay.bidiMode = bidiMode
        overlay.arabicFontName = themeManager.currentTheme.arabicFontName
        container.addSubview(overlay)

        // Store references
        context.coordinator.terminalView = terminalView
        context.coordinator.overlayView = overlay
        container.coordinator = context.coordinator

        // Start shell
        DispatchQueue.main.async {
            let allowedShells = ["/bin/zsh", "/bin/bash", "/bin/sh",
                                 "/usr/local/bin/zsh", "/usr/local/bin/bash",
                                 "/usr/local/bin/fish", "/opt/homebrew/bin/zsh",
                                 "/opt/homebrew/bin/bash", "/opt/homebrew/bin/fish"]

            let requested = UserDefaults.standard.string(forKey: "shellPath")
                ?? ProcessInfo.processInfo.environment["SHELL"]
                ?? "/bin/zsh"

            let shell: String
            if requested.hasPrefix("/"),
               FileManager.default.isExecutableFile(atPath: requested),
               allowedShells.contains(requested) || FileManager.default.fileExists(atPath: requested) {
                shell = requested
            } else {
                shell = "/bin/zsh"
            }

            // Working directory: if "current" is selected and tab has a real dir, use it
            let newTabDir = UserDefaults.standard.string(forKey: "newTabWorkingDir") ?? "home"
            let workDir: String?
            switch newTabDir {
            case "current":
                let dir = self.tab.workingDirectory
                workDir = (dir != NSHomeDirectory()) ? dir : nil
            case "root":
                workDir = "/"
            default:
                workDir = nil // home directory (default)
            }

            terminalView.startProcess(
                executable: shell,
                args: ["--login"],
                environment: nil,
                execName: nil,
                currentDirectory: workDir
            )
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let tv = context.coordinator.terminalView {
            applyTheme(to: tv)
            applyCursorStyle(to: tv)
            tv.optionAsMetaKey = optionAsMeta
            tv.bellSoundEnabled = bellSound
            tv.bellBounceEnabled = bellBounce

            // Update scrollback via the proper API
            tv.changeScrollback(scrollbackLines)

            tv.window?.makeFirstResponder(tv)
        }

        if let vibrancy = context.coordinator.vibrancyView {
            vibrancy.isHidden = (opacity >= 1.0)
        }

        if let overlay = context.coordinator.overlayView {
            overlay.bidiMode = bidiMode
            overlay.arabicFontName = themeManager.currentTheme.arabicFontName
            overlay.needsDisplay = true
        }

        context.coordinator.titleBarStyle = titleBarStyle
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    // MARK: - Apply Settings

    private func applyTheme(to terminalView: TarminalTerminalView) {
        let theme = themeManager.currentTheme

        let bgAlpha = CGFloat(opacity)
        let bgColor = theme.background.nsColor.withAlphaComponent(bgAlpha)
        terminalView.nativeBackgroundColor = bgColor
        terminalView.nativeForegroundColor = theme.foreground.nsColor

        terminalView.layer?.isOpaque = (opacity >= 1.0)
        terminalView.layer?.backgroundColor = bgColor.cgColor

        let font = NSFont(name: theme.fontName, size: theme.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        terminalView.font = font

        terminalView.caretColor = theme.cursor.nsColor
        terminalView.selectedTextBackgroundColor = theme.selection.nsColor

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

    private func applyCursorStyle(to terminalView: TarminalTerminalView) {
        let terminal = terminalView.getTerminal()
        let style: CursorStyle
        switch cursorStyle {
        case "underline":
            style = cursorBlink ? .blinkUnderline : .steadyUnderline
        case "bar":
            style = cursorBlink ? .blinkBar : .steadyBar
        default:
            style = cursorBlink ? .blinkBlock : .steadyBlock
        }
        // Use setCursorStyle — direct assignment to options.cursorStyle
        // bypasses the delegate and never updates the caret view
        terminal.setCursorStyle(style)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab
        var terminalView: TarminalTerminalView?
        var overlayView: BiDiOverlayView?
        var vibrancyView: NSVisualEffectView?
        private var refreshTimer: Timer?

        var titleBarStyle: String = "directory"

        init(tab: TerminalTab) {
            self.tab = tab
            super.init()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.overlayView?.needsDisplay = true
            }
        }

        deinit { refreshTimer?.invalidate() }

        /// Called by TerminalDropView when files are dropped
        func handleFileDrop(paths: [String]) {
            guard let tv = terminalView else { return }
            let escaped = paths.map { path in
                path.replacingOccurrences(of: " ", with: "\\ ")
                    .replacingOccurrences(of: "(", with: "\\(")
                    .replacingOccurrences(of: ")", with: "\\)")
                    .replacingOccurrences(of: "'", with: "\\'")
            }
            let text = escaped.joined(separator: " ")
            tv.send(txt: text)
        }

        // MARK: LocalProcessTerminalViewDelegate

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async { [self] in
                let rawTitle = title.isEmpty ? "zsh" : title
                self.tab.title = rawTitle

                switch self.titleBarStyle {
                case "shell":
                    source.window?.title = rawTitle
                case "directory":
                    let dir = (self.tab.workingDirectory as NSString).lastPathComponent
                    source.window?.title = dir.isEmpty ? rawTitle : dir
                case "none":
                    source.window?.title = ""
                default:
                    source.window?.title = rawTitle
                }
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async {
                    self.tab.workingDirectory = dir
                    if self.titleBarStyle == "directory" {
                        let last = (dir as NSString).lastPathComponent
                        source.window?.title = last.isEmpty ? "~" : last
                    }
                }
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { self.tab.isTerminated = true }
        }
    }
}

// MARK: - Drop View

class TerminalDropView: NSView {
    weak var coordinator: TerminalContainerView.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .png, .tiff, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canRead = sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ])
        return canRead ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else { return false }

        let paths = urls.map(\.path)
        coordinator?.handleFileDrop(paths: paths)
        return true
    }
}
