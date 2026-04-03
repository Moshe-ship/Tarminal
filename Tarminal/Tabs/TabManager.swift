import SwiftUI

// MARK: - Session State (persisted to disk)

struct SavedTab: Codable {
    let workingDirectory: String
    let tabColor: String
    let title: String
}

struct SavedSession: Codable {
    let tabs: [SavedTab]
    let selectedIndex: Int
}

// MARK: - Terminal Tab

class TerminalTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var workingDirectory: String
    @Published var isTerminated: Bool = false
    @Published var tabColor: TabColor = .none
    @Published var hasActivity: Bool = false

    enum TabColor: String, CaseIterable {
        case none, red, orange, yellow, green, blue, purple, pink

        var color: Color? {
            switch self {
            case .none: return nil
            case .red: return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green: return .green
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            }
        }

        var displayName: String {
            rawValue == "none" ? "Default" : rawValue.capitalized
        }
    }

    init(title: String = "zsh", workingDirectory: String? = nil, tabColor: TabColor = .none) {
        self.title = title
        self.workingDirectory = workingDirectory ?? NSHomeDirectory()
        self.tabColor = tabColor
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

    private static let sessionKey = "com.tarminal.savedSession"

    init() {
        restoreSession()
    }

    var currentTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }

    var selectedIndex: Int? {
        tabs.firstIndex { $0.id == selectedTabId }
    }

    // MARK: Tab Operations

    func addTab() {
        let currentDir = currentTab?.workingDirectory
        let tab = TerminalTab(workingDirectory: currentDir)
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

    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < tabs.count,
              destinationIndex >= 0, destinationIndex < tabs.count else { return }
        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)
    }

    // MARK: Session Persistence

    func saveSession() {
        let savedTabs = tabs.map { tab in
            SavedTab(
                workingDirectory: tab.workingDirectory,
                tabColor: tab.tabColor.rawValue,
                title: tab.title
            )
        }
        let session = SavedSession(
            tabs: savedTabs,
            selectedIndex: selectedIndex ?? 0
        )
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Self.sessionKey)
        }
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionKey),
              let session = try? JSONDecoder().decode(SavedSession.self, from: data),
              !session.tabs.isEmpty else { return }

        for saved in session.tabs {
            let color = TerminalTab.TabColor(rawValue: saved.tabColor) ?? .none
            let tab = TerminalTab(
                title: saved.title,
                workingDirectory: saved.workingDirectory,
                tabColor: color
            )
            tabs.append(tab)
        }

        let idx = min(session.selectedIndex, tabs.count - 1)
        selectedTabId = tabs[idx].id
    }
}
