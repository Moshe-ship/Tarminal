import SwiftUI
import AppKit

// MARK: - Colored circle images for menus (NSMenu strips SwiftUI foregroundColor)

private func coloredCircleImage(_ color: NSColor, size: CGFloat = 12) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    image.unlockFocus()
    image.isTemplate = false
    return image
}

private let colorImages: [TerminalTab.TabColor: NSImage] = {
    var map: [TerminalTab.TabColor: NSImage] = [:]
    let nsColors: [TerminalTab.TabColor: NSColor] = [
        .red: NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1),
        .orange: NSColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 1),
        .yellow: NSColor(red: 1.0, green: 0.84, blue: 0.04, alpha: 1),
        .green: NSColor(red: 0.16, green: 0.78, blue: 0.25, alpha: 1),
        .blue: NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1),
        .purple: NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1),
        .pink: NSColor(red: 1.0, green: 0.18, blue: 0.53, alpha: 1),
    ]
    for (key, nsColor) in nsColors {
        map[key] = coloredCircleImage(nsColor)
    }
    return map
}()

// MARK: - Tab Bar View

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

                // No dividers — rounded tab shapes provide separation
            }

            Spacer()

            Button(action: { tabManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(height: 28)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func tabContextMenu(for tab: TerminalTab) -> some View {
        // Color picker with real colored NSImages that render in NSMenu
        Menu("Tab Color") {
            Button(action: { tab.tabColor = .none }) {
                Label {
                    Text("Default")
                } icon: {
                    Image(systemName: tab.tabColor == .none ? "checkmark.circle" : "circle")
                }
            }

            Divider()

            ForEach(TerminalTab.TabColor.allCases.filter { $0 != .none }, id: \.self) { tabColor in
                Button(action: { tab.tabColor = tabColor }) {
                    Label {
                        Text(tabColor.displayName)
                    } icon: {
                        if let nsImage = colorImages[tabColor] {
                            Image(nsImage: nsImage)
                        }
                    }
                }
            }
        }

        Divider()

        Button("New Tab") {
            tabManager.addTab()
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
}

// MARK: - Tab Item View

struct TabItemView: View {
    @ObservedObject var tab: TerminalTab
    let index: Int
    let isSelected: Bool
    let isOnly: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    private var effectiveColor: Color? {
        tab.tabColor.color
    }

    var body: some View {
        HStack(spacing: 5) {
            // Color dot or activity indicator
            if let color = effectiveColor {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            } else if tab.hasActivity && !isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
            }

            // Tab title
            Text(tab.displayTitle)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            // Close button
            if !isOnly && (isHovering || isSelected) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .background(
                            isHovering ? Color.primary.opacity(0.08) : Color.clear
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 100, maxWidth: 180, maxHeight: .infinity)
        .background(tabBackground)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .padding(.vertical, 3)
        .padding(.horizontal, 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }

    private var tabBackground: Color {
        if let color = effectiveColor, isSelected {
            return color.opacity(0.12)
        }
        if isSelected {
            return Color.primary.opacity(0.1)
        }
        if isHovering {
            return Color.primary.opacity(0.05)
        }
        return .clear
    }
}

// MARK: - Drop Delegate

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
