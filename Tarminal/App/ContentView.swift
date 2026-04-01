import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tabManager: TabManager

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
    }
}
