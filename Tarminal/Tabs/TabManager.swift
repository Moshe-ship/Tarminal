import SwiftUI

// MARK: - Tab Group

class TabGroup: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var color: Color

    init(name: String = "Default", color: Color = .clear) {
        self.name = name
        self.color = color
    }

    static let groupColors: [Color] = [
        .clear, .red, .orange, .yellow, .green, .blue, .purple, .pink
    ]

    static let colorNames: [Color: String] = [
        .clear: "None", .red: "Red", .orange: "Orange", .yellow: "Yellow",
        .green: "Green", .blue: "Blue", .purple: "Purple", .pink: "Pink"
    ]
}

// MARK: - Terminal Tab

class TerminalTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var workingDirectory: String
    @Published var isActive: Bool = false
    @Published var isTerminated: Bool = false
    @Published var groupId: UUID?

    init(title: String = "zsh", groupId: UUID? = nil) {
        self.title = title
        self.workingDirectory = NSHomeDirectory()
        self.groupId = groupId
    }

    var displayTitle: String {
        if isTerminated { return "[\(title)]" }
        let lastComponent = (workingDirectory as NSString).lastPathComponent
        return lastComponent.isEmpty ? title : lastComponent
    }
}

// MARK: - Tab Manager

class TabManager: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabId: UUID?
    @Published var groups: [TabGroup] = []

    var currentTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }

    var selectedIndex: Int? {
        tabs.firstIndex { $0.id == selectedTabId }
    }

    // MARK: Tab Operations

    func addTab(groupId: UUID? = nil) {
        // Inherit working directory from the currently selected tab
        let currentDir = currentTab?.workingDirectory
        let tab = TerminalTab(groupId: groupId)
        if let dir = currentDir {
            tab.workingDirectory = dir
        }
        tabs.append(tab)
        selectedTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        let wasSelected = selectedTabId == id
        let idx = tabs.firstIndex { $0.id == id }
        tabs.removeAll { $0.id == id }

        if wasSelected {
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

    /// Move a tab from one position to another (for drag reorder)
    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < tabs.count,
              destinationIndex >= 0, destinationIndex < tabs.count else { return }
        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)
    }

    // MARK: Group Operations

    func createGroup(name: String, color: Color) -> TabGroup {
        let group = TabGroup(name: name, color: color)
        groups.append(group)
        return group
    }

    func deleteGroup(_ id: UUID) {
        // Unassign tabs from this group
        for tab in tabs where tab.groupId == id {
            tab.groupId = nil
        }
        groups.removeAll { $0.id == id }
    }

    func assignTabToGroup(tabId: UUID, groupId: UUID?) {
        if let tab = tabs.first(where: { $0.id == tabId }) {
            tab.groupId = groupId
        }
    }

    func group(for tab: TerminalTab) -> TabGroup? {
        guard let gid = tab.groupId else { return nil }
        return groups.first { $0.id == gid }
    }

    func tabs(in groupId: UUID) -> [TerminalTab] {
        tabs.filter { $0.groupId == groupId }
    }
}
