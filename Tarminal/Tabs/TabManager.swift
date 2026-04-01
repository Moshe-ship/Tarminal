import SwiftUI

class TerminalTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var isActive: Bool = false

    init(title: String = "zsh") {
        self.title = title
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabId: UUID?

    var currentTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }

    func addTab() {
        let tab = TerminalTab()
        tabs.append(tab)
        selectedTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTabId == id {
            selectedTabId = tabs.last?.id
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
}
