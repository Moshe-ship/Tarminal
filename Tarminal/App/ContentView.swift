import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if tabManager.tabs.count > 1 {
                TabBarView()
            }

            // Terminal
            if let currentTab = tabManager.currentTab {
                TerminalContainerView(tab: currentTab)
                    .id(currentTab.id)
            }
        }
        .background(Color(nsColor: .black))
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.addTab()
            }
        }
    }
}
