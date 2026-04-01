import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                TabItemView(
                    tab: tab,
                    index: index + 1,
                    isSelected: tab.id == tabManager.selectedTabId,
                    isOnly: tabManager.tabs.count == 1,
                    onSelect: { tabManager.selectTab(tab.id) },
                    onClose: { tabManager.closeTab(tab.id) }
                )

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
}

struct TabItemView: View {
    @ObservedObject var tab: TerminalTab
    let index: Int
    let isSelected: Bool
    let isOnly: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
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
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isSelected ? Color.green.opacity(0.5) : .clear),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}
