import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager
    @AppStorage("confirmClose") private var confirmClose: Bool = true
    @State private var tabToClose: UUID?
    @State private var showCloseConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar — always show (like iTerm2)
            TabBarView()

            // Active terminal
            if let currentTab = tabManager.currentTab {
                TerminalContainerView(tab: currentTab)
                    .id(currentTab.id)
            } else {
                // Empty state
                VStack {
                    Spacer()
                    Text("ترمنال")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.white.opacity(0.15))
                    Text("Cmd+T to open a new tab")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.1))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .background(Color(nsColor: NSColor(white: 0.08, alpha: 1)))
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

// MARK: - Close Tab Handler (passed through environment)

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
