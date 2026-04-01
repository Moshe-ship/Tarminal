import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizesSubviews = true

        // Create terminal view
        let terminalView = LocalProcessTerminalView(frame: container.bounds)
        terminalView.autoresizingMask = [.width, .height]

        // Configure appearance
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .init(white: 0.92, alpha: 1)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        // Set process delegate
        terminalView.processDelegate = context.coordinator

        // Add terminal to container
        container.addSubview(terminalView)

        // Create BiDi overlay (sits on top, redraws RTL lines)
        let overlay = BiDiOverlayView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.terminalView = terminalView
        container.addSubview(overlay)

        // Store references
        context.coordinator.terminalView = terminalView
        context.coordinator.overlayView = overlay

        // Start shell process
        DispatchQueue.main.async {
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
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
        context.coordinator.terminalView?.window?.makeFirstResponder(context.coordinator.terminalView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab
        var terminalView: LocalProcessTerminalView?
        var overlayView: BiDiOverlayView?

        // Timer for refreshing BiDi overlay
        private var refreshTimer: Timer?

        init(tab: TerminalTab) {
            self.tab = tab
            super.init()
            // Refresh overlay periodically to catch terminal updates
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.overlayView?.needsDisplay = true
            }
        }

        deinit {
            refreshTimer?.invalidate()
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async {
                self.tab.title = title.isEmpty ? "zsh" : title
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                DispatchQueue.main.async {
                    self.tab.workingDirectory = dir
                }
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                self.tab.isTerminated = true
            }
        }
    }
}
