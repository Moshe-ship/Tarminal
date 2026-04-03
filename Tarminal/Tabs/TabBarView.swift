import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.closeTabHandler) private var closeTabHandler
    @State private var draggedTabId: UUID?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                TabItemView(
                    tab: tab,
                    index: index + 1,
                    isSelected: tab.id == tabManager.selectedTabId,
                    isOnly: tabManager.tabs.count == 1,
                    groupColor: tabManager.group(for: tab)?.color ?? .clear,
                    onSelect: { tabManager.selectTab(tab.id) },
                    onClose: { closeTabHandler(tab.id) }
                )
                .onDrag {
                    draggedTabId = tab.id
                    return NSItemProvider(object: tab.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: TabDropDelegate(
                    tabManager: tabManager,
                    targetTabId: tab.id,
                    draggedTabId: $draggedTabId
                ))
                .contextMenu {
                    tabContextMenu(for: tab)
                }

                // Separator between tabs
                if tab.id != tabManager.tabs.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1, height: 20)
                }
            }

            Spacer()

            // New tab button
            Button(action: { tabManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.05)),
            alignment: .bottom
        )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func tabContextMenu(for tab: TerminalTab) -> some View {
        // Group color submenu
        Menu("Set Color") {
            ForEach(TabGroup.groupColors, id: \.self) { color in
                Button(action: {
                    setTabColor(tab: tab, color: color)
                }) {
                    HStack {
                        if color == .clear {
                            Image(systemName: "xmark.circle")
                            Text("None")
                        } else {
                            Image(systemName: "circle.fill")
                                .foregroundColor(color)
                            Text(TabGroup.colorNames[color] ?? "Color")
                        }
                    }
                }
            }
        }

        // Group assignment submenu
        if !tabManager.groups.isEmpty {
            Menu("Move to Group") {
                Button("No Group") {
                    tabManager.assignTabToGroup(tabId: tab.id, groupId: nil)
                }
                Divider()
                ForEach(tabManager.groups) { group in
                    Button(group.name) {
                        tabManager.assignTabToGroup(tabId: tab.id, groupId: group.id)
                    }
                }
            }
        }

        Divider()

        Button("New Tab") {
            tabManager.addTab(groupId: tab.groupId)
        }

        if tabManager.tabs.count > 1 {
            Button("Close Tab") {
                closeTabHandler(tab.id)
            }

            Button("Close Other Tabs") {
                let others = tabManager.tabs.filter { $0.id != tab.id }.map(\.id)
                tabManager.selectTab(tab.id)
                for id in others {
                    closeTabHandler(id)
                }
            }
        }
    }

    private func setTabColor(tab: TerminalTab, color: Color) {
        if color == .clear {
            tabManager.assignTabToGroup(tabId: tab.id, groupId: nil)
        } else {
            // Find or create a group with this color
            if let existing = tabManager.groups.first(where: { $0.color == color }) {
                tabManager.assignTabToGroup(tabId: tab.id, groupId: existing.id)
            } else {
                let name = TabGroup.colorNames[color] ?? "Group"
                let group = tabManager.createGroup(name: name, color: color)
                tabManager.assignTabToGroup(tabId: tab.id, groupId: group.id)
            }
        }
    }
}

// MARK: - Tab Item View

struct TabItemView: View {
    @ObservedObject var tab: TerminalTab
    let index: Int
    let isSelected: Bool
    let isOnly: Bool
    let groupColor: Color
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // Group color dot
            if groupColor != .clear {
                Circle()
                    .fill(groupColor)
                    .frame(width: 6, height: 6)
            }

            // Tab number indicator
            Text("\(index)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .green.opacity(0.7) : .white.opacity(0.2))
                .frame(width: 14)

            // Tab title
            Text(tab.displayTitle)
                .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            // Close button (show on hover or selected, hide if only tab)
            if !isOnly && (isHovering || isSelected) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .background(
                            isHovering ? Color.white.opacity(0.1) : Color.clear
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 120, maxWidth: 200, maxHeight: .infinity)
        .background(
            isSelected
                ? Color(nsColor: NSColor(white: 0.16, alpha: 1))
                : isHovering
                    ? Color(nsColor: NSColor(white: 0.12, alpha: 1))
                    : Color.clear
        )
        .overlay(
            // Bottom accent: group color if grouped, green if selected
            Rectangle()
                .frame(height: 2)
                .foregroundColor(
                    groupColor != .clear
                        ? groupColor.opacity(isSelected ? 0.8 : 0.4)
                        : (isSelected ? Color.green.opacity(0.5) : .clear)
                ),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Drop Delegate (Tab Reorder)

struct TabDropDelegate: DropDelegate {
    let tabManager: TabManager
    let targetTabId: UUID
    @Binding var draggedTabId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggedTabId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTabId,
              draggedId != targetTabId,
              let fromIndex = tabManager.tabs.firstIndex(where: { $0.id == draggedId }),
              let toIndex = tabManager.tabs.firstIndex(where: { $0.id == targetTabId })
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            tabManager.moveTab(from: fromIndex, to: toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedTabId != nil
    }
}
