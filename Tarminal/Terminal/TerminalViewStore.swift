import AppKit

/// Caches terminal views to prevent SwiftUI from killing shell processes
/// when it recreates NSViewRepresentable views during ForEach updates.
///
/// Without this cache, when a new tab is added, SwiftUI may tear down and
/// recreate existing NSViewRepresentable views. When a TarminalTerminalView
/// is deallocated, its LocalProcess DispatchIO cleanup closes the PTY file
/// descriptor, sending SIGHUP to the child shell — killing any running
/// process (e.g. Claude Code).
final class TerminalViewStore {
    static let shared = TerminalViewStore()
    private init() {}

    private var terminals: [UUID: TarminalTerminalView] = [:]

    func terminal(for tabId: UUID) -> TarminalTerminalView? {
        terminals[tabId]
    }

    func store(_ terminal: TarminalTerminalView, for tabId: UUID) {
        terminals[tabId] = terminal
    }

    func remove(tabId: UUID) {
        terminals.removeValue(forKey: tabId)
    }
}
