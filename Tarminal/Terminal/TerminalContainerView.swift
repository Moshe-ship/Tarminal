import SwiftUI
import SwiftTerm

struct TerminalContainerView: NSViewRepresentable {
    let tab: TerminalTab

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Configure appearance
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .init(white: 0.92, alpha: 1)

        // Set font
        let fontSize: CGFloat = 14
        terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Set process delegate
        terminalView.processDelegate = context.coordinator

        // Start shell process after a brief delay to ensure view is in window
        DispatchQueue.main.async {
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let home = NSHomeDirectory()

            terminalView.startProcess(
                executable: shell,
                args: ["--login"],
                environment: nil,
                execName: nil
            )

            // Make the terminal the first responder for keyboard input
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Ensure terminal has focus
        nsView.window?.makeFirstResponder(nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let tab: TerminalTab

        init(tab: TerminalTab) {
            self.tab = tab
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async {
                self.tab.title = title.isEmpty ? "zsh" : title
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}
