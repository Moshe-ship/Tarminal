import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab
    var tabManager: TabManager?
    @ObservedObject var themeManager = ThemeManager.shared
    @AppStorage("opacity") private var opacity: Double = 1.0
    @AppStorage("cursorStyle") private var cursorStyle: String = "block"
    @AppStorage("cursorBlink") private var cursorBlink: Bool = false
    @AppStorage("optionAsMeta") private var optionAsMeta: Bool = false
    @AppStorage("bellSound") private var bellSound: Bool = true
    @AppStorage("bellBounce") private var bellBounce: Bool = false
    @AppStorage("titleBarStyle") private var titleBarStyle: String = "directory"
    @AppStorage("scrollbackLines") private var scrollbackLines: Int = 10000
    @AppStorage("useMetalRenderer") private var useMetalRenderer: Bool = true

    func makeNSView(context: Context) -> NSView {
        let container = TerminalDropView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizesSubviews = true

        let vibrancy = NSVisualEffectView(frame: container.bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.blendingMode = .behindWindow
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.isHidden = (opacity >= 1.0)
        container.addSubview(vibrancy)
        context.coordinator.vibrancyView = vibrancy

        // Reuse cached terminal view if available — prevents process kill
        // when SwiftUI tears down and recreates NSViewRepresentable views.
        if let cached = TerminalViewStore.shared.terminal(for: tab.id) {
            cached.removeFromSuperview()
            cached.frame = container.bounds
            cached.processDelegate = context.coordinator
            container.addSubview(cached)
            context.coordinator.terminalView = cached
            context.coordinator.tabManager = tabManager
            context.coordinator.titleBarStyle = titleBarStyle
            container.coordinator = context.coordinator
            return container
        }

        let terminalView = TarminalTerminalView(frame: container.bounds)
        terminalView.autoresizingMask = [.width, .height]

        terminalView.bellSoundEnabled = bellSound
        terminalView.bellBounceEnabled = bellBounce

        applyTheme(to: terminalView)
        applyCursorStyle(to: terminalView)
        terminalView.optionAsMetaKey = optionAsMeta
        terminalView.changeScrollback(scrollbackLines)
        terminalView.linkHighlightMode = .hover

        terminalView.processDelegate = context.coordinator
        context.coordinator.titleBarStyle = titleBarStyle
        container.addSubview(terminalView)

        context.coordinator.terminalView = terminalView
        context.coordinator.tabManager = tabManager
        container.coordinator = context.coordinator

        // Cache the terminal view so it survives SwiftUI view recreation
        TerminalViewStore.shared.store(terminalView, for: tab.id)

        // Enable Metal AFTER view is in hierarchy (SwiftTerm requires window context)
        DispatchQueue.main.async {
            if self.useMetalRenderer {
                terminalView.enableMetal()
            }
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

            let newTabDir = UserDefaults.standard.string(forKey: "newTabWorkingDir") ?? "home"
            let workDir: String?
            switch newTabDir {
            case "current":
                let dir = self.tab.workingDirectory
                workDir = (dir != NSHomeDirectory()) ? dir : nil
            case "root":
                workDir = "/"
            default:
                workDir = nil
            }

            // Build environment with Touch ID SSH support
            var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")

            // Inherit PATH from parent process (SwiftTerm doesn't by default)
            if let path = ProcessInfo.processInfo.environment["PATH"] {
                env.append("PATH=\(path)")
            }

            // Enable Secure Enclave SSH keys (Touch ID for SSH)
            if FileManager.default.fileExists(atPath: "/usr/lib/ssh-keychain.dylib") {
                env.append("SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib")
            }

            terminalView.startProcess(executable: shell, args: ["--login"], environment: env, execName: nil, currentDirectory: workDir)
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
            tv.changeScrollback(scrollbackLines)

            // Apply Metal toggle to running terminals
            if useMetalRenderer && !tv.isUsingMetalRenderer {
                tv.enableMetal()
            } else if !useMetalRenderer && tv.isUsingMetalRenderer {
                try? tv.setUseMetal(false)
            }

            // Only steal focus for the selected tab — prevents background
            // tabs from grabbing first responder and displacing the cursor.
            if tabManager?.selectedTabId == tab.id {
                tv.window?.makeFirstResponder(tv)
            }
        }
        if let vibrancy = context.coordinator.vibrancyView {
            vibrancy.isHidden = (opacity >= 1.0)
        }
        context.coordinator.titleBarStyle = titleBarStyle
    }

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab) }

    private func applyTheme(to tv: TarminalTerminalView) {
        let theme = themeManager.currentTheme
        let bgColor = theme.background.nsColor.withAlphaComponent(CGFloat(opacity))
        tv.nativeBackgroundColor = bgColor
        tv.nativeForegroundColor = theme.foreground.nsColor
        tv.layer?.isOpaque = (opacity >= 1.0)
        tv.layer?.backgroundColor = bgColor.cgColor
        tv.font = NSFont(name: theme.fontName, size: theme.fontSize) ?? NSFont.monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        tv.caretColor = theme.cursor.nsColor
        tv.selectedTextBackgroundColor = theme.selection.nsColor
        if theme.ansiColors.count == 16 {
            tv.installColors(theme.ansiColors.map { SwiftTerm.Color(red: UInt16($0.r * 65535), green: UInt16($0.g * 65535), blue: UInt16($0.b * 65535)) })
        }
    }

    private func applyCursorStyle(to tv: TarminalTerminalView) {
        let terminal = tv.getTerminal()
        let style: CursorStyle
        switch cursorStyle {
        case "underline": style = cursorBlink ? .blinkUnderline : .steadyUnderline
        case "bar": style = cursorBlink ? .blinkBar : .steadyBar
        default: style = cursorBlink ? .blinkBlock : .steadyBlock
        }
        terminal.setCursorStyle(style)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab
        weak var tabManager: TabManager?
        var terminalView: TarminalTerminalView?
        var vibrancyView: NSVisualEffectView?
        var titleBarStyle: String = "directory"

        init(tab: TerminalTab) { self.tab = tab; super.init() }

        func handleFileDrop(paths: [String]) {
            guard let tv = terminalView else { return }
            let escaped = paths.map { $0.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)").replacingOccurrences(of: "'", with: "\\'") }
            tv.send(txt: escaped.joined(separator: " "))
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async { [self] in
                let t = title.isEmpty ? "zsh" : title
                self.tab.title = t
                self.terminalView?.tabTitle = t

                // Mark activity on background tabs
                if let tabManager = self.tabManager, tabManager.selectedTabId != self.tab.id {
                    self.tab.hasActivity = true
                }

                switch self.titleBarStyle {
                case "shell": source.window?.title = t
                case "directory": source.window?.title = (self.tab.workingDirectory as NSString).lastPathComponent.isEmpty ? t : (self.tab.workingDirectory as NSString).lastPathComponent
                case "none": source.window?.title = ""
                default: source.window?.title = t
                }
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async {
                    self.tab.workingDirectory = dir
                    if self.titleBarStyle == "directory" {
                        source.window?.title = (dir as NSString).lastPathComponent.isEmpty ? "~" : (dir as NSString).lastPathComponent
                    }
                }
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                self.tab.isTerminated = true
                NotificationManager.shared.notifyProcessFinished(tabTitle: self.tab.displayTitle)
            }
        }
    }
}

class TerminalDropView: NSView {
    weak var coordinator: TerminalContainerView.Coordinator?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL, .png, .tiff, .string]) }
    required init?(coder: NSCoder) { super.init(coder: coder); registerForDraggedTypes([.fileURL, .png, .tiff, .string]) }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : [] }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        coordinator?.handleFileDrop(paths: urls.map(\.path)); return true
    }
}
