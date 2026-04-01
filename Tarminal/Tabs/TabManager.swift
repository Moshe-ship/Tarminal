import SwiftUI

class TerminalTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var workingDirectory: String
    @Published var isActive: Bool = false
    @Published var isTerminated: Bool = false

    init(title: String = "zsh") {
        self.title = title
        self.workingDirectory = NSHomeDirectory()
    }

    var displayTitle: String {
        if isTerminated { return "[\(title)]" }
        // Show last path component of working directory
        let lastComponent = (workingDirectory as NSString).lastPathComponent
        return lastComponent.isEmpty ? title : lastComponent
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabId: UUID?

    var currentTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }

    var selectedIndex: Int? {
        tabs.firstIndex { $0.id == selectedTabId }
    }

    func addTab() {
        let tab = TerminalTab()
        tabs.append(tab)
        selectedTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return } // Keep at least one tab
        let wasSelected = selectedTabId == id
        let idx = tabs.firstIndex { $0.id == id }
        tabs.removeAll { $0.id == id }

        if wasSelected {
            // Select adjacent tab
            if let idx = idx {
                let newIdx = min(idx, tabs.count - 1)
                selectedTabId = tabs[newIdx].id
            } else {
                selectedTabId = tabs.last?.id
            }
        }
    }

    func closeCurrentTab() {
        if let id = selectedTabId {
            closeTab(id)
        }
    }

    func selectTab(_ id: UUID) {
        selectedTabId = id
    }

    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTabId = tabs[index].id
    }

    func nextTab() {
        guard let idx = selectedIndex else { return }
        let next = (idx + 1) % tabs.count
        selectedTabId = tabs[next].id
    }

    func previousTab() {
        guard let idx = selectedIndex else { return }
        let prev = idx > 0 ? idx - 1 : tabs.count - 1
        selectedTabId = tabs[prev].id
    }
}
