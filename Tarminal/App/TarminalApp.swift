import SwiftUI

@main
struct TarminalApp: App {
    @StateObject private var tabManager = TabManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tabManager)
                .frame(minWidth: 600, minHeight: 400)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    tabManager.saveSession()
                }
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
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

            // Find (Cmd+F) — routes to SwiftTerm's built-in find bar
            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: NSMenuItem(title: "", action: nil, keyEquivalent: "").then {
                        $0.tag = NSTextFinder.Action.showFindInterface.rawValue
                    })
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: NSMenuItem(title: "", action: nil, keyEquivalent: "").then {
                        $0.tag = NSTextFinder.Action.nextMatch.rawValue
                    })
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: NSMenuItem(title: "", action: nil, keyEquivalent: "").then {
                        $0.tag = NSTextFinder.Action.previousMatch.rawValue
                    })
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
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

// Helper to configure NSMenuItem inline
extension NSMenuItem {
    func then(_ configure: (NSMenuItem) -> Void) -> NSMenuItem {
        configure(self)
        return self
    }
}
