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

                if tab.id != tabManager.tabs.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1, height: 20)
                }
            }

            Spacer()

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
        HStack(spacing: 6) {
            // Color dot or activity indicator
            if let color = effectiveColor {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            } else if tab.hasActivity && !isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 5, height: 5)
            }

            // Tab number
            Text("\(index)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .green.opacity(0.7) : (tab.hasActivity ? .blue.opacity(0.7) : .white.opacity(0.2)))
                .frame(width: 14)

            // Tab title
            Text(tab.displayTitle)
                .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            // Close button
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
        .background(tabBackground)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(bottomAccentColor),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }

    private var tabBackground: Color {
        if let color = effectiveColor, isSelected {
            return color.opacity(0.12)
        }
        if isSelected {
            return Color(nsColor: NSColor(white: 0.16, alpha: 1))
        }
        if isHovering {
            return Color(nsColor: NSColor(white: 0.12, alpha: 1))
        }
        return .clear
    }

    private var bottomAccentColor: Color {
        if let color = effectiveColor {
            return color.opacity(isSelected ? 0.8 : 0.4)
        }
        return isSelected ? Color.green.opacity(0.5) : .clear
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
