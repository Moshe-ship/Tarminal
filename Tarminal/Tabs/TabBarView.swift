import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabManager.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: tab.id == tabManager.selectedTabId,
                    onSelect: { tabManager.selectTab(tab.id) },
                    onClose: { tabManager.closeTab(tab.id) }
                )
            }

            Spacer()

            Button(action: { tabManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: NSColor(white: 0.12, alpha: 1)))
    }
}

struct TabItemView: View {
    @ObservedObject var tab: TerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.title)
                .font(.system(size: 11.5))
                .foregroundColor(isSelected ? .white : .gray)
                .lineLimit(1)

            if isHovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(
            isSelected
                ? Color(nsColor: NSColor(white: 0.18, alpha: 1))
                : Color.clear
        )
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isSelected ? Color.green.opacity(0.6) : .clear),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}
