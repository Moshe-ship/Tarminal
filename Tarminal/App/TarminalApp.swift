import SwiftUI

@main
struct TarminalApp: App {
    @StateObject private var tabManager = TabManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabManager)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 900, height: 600)
        .commands {
            // Tab commands
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    tabManager.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Close Tab") {
                    tabManager.closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            // Tab navigation
            CommandMenu("Tab") {
                Button("Next Tab") {
                    tabManager.nextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    tabManager.previousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                // Cmd+1-9 tab switching
                ForEach(1...9, id: \.self) { num in
                    Button("Tab \(num)") {
                        tabManager.selectTab(at: num - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(num))), modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
