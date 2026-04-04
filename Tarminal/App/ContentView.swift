import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @AppStorage("confirmClose") private var confirmClose: Bool = true
    @State private var tabToClose: UUID?
    @State private var showCloseConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()

            // Keep ALL terminal views alive — show/hide based on active tab.
            // Using .id() would destroy the NSView + shell process on every switch.
            ZStack {
                if tabManager.tabs.isEmpty {
                    VStack {
                        Spacer()
                        Text("ترمنال")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("Cmd+T to open a new tab")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.2))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    ForEach(tabManager.tabs) { tab in
                        TerminalContainerView(tab: tab, tabManager: tabManager)
                            .opacity(tab.id == tabManager.selectedTabId ? 1 : 0)
                            .allowsHitTesting(tab.id == tabManager.selectedTabId)
                    }
                }
            }
            .onChange(of: tabManager.selectedTabId) { newId in
                tabManager.tabs.first { $0.id == newId }?.hasActivity = false
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.addTab()
            }
        }
        .alert("Close Tab?", isPresented: $showCloseConfirm) {
            Button("Close", role: .destructive) {
                if let id = tabToClose {
                    tabManager.closeTab(id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This tab has a running process. Are you sure you want to close it?")
        }
        .environment(\.closeTabHandler, CloseTabHandler { tabId in
            let tab = tabManager.tabs.first { $0.id == tabId }
            if confirmClose, let tab, !tab.isTerminated {
                tabToClose = tabId
                showCloseConfirm = true
            } else {
                tabManager.closeTab(tabId)
            }
        })
    }
}

// MARK: - Close Tab Handler

struct CloseTabHandler {
    let close: (UUID) -> Void
    func callAsFunction(_ id: UUID) { close(id) }
}

private struct CloseTabHandlerKey: EnvironmentKey {
    static let defaultValue = CloseTabHandler { _ in }
}

extension EnvironmentValues {
    var closeTabHandler: CloseTabHandler {
        get { self[CloseTabHandlerKey.self] }
        set { self[CloseTabHandlerKey.self] = newValue }
    }
}
