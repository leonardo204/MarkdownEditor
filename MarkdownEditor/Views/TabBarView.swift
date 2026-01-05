import SwiftUI

// MARK: - 탭 바 뷰
struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    let onNewTab: () -> Void

    // 탭 바 색상
    private let tabBarBackground = Color(NSColor.windowBackgroundColor).opacity(0.95)

    var body: some View {
        HStack(spacing: 0) {
            // 탭들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            tab: tab,
                            isSelected: index == tabManager.selectedTabIndex,
                            onSelect: {
                                tabManager.selectTab(at: index)
                            },
                            onClose: {
                                _ = tabManager.closeTab(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }

            Spacer()

            // 새 탭 버튼
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .padding(.top, 4)
        }
        .frame(height: 32)
        .background(tabBarBackground)
    }
}

// MARK: - 개별 탭 아이템 뷰
struct TabItemView: View {
    @ObservedObject var tab: TabItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    // 색상
    private var backgroundColor: Color {
        if isSelected {
            return Color(NSColor.controlBackgroundColor)
        } else if isHovering {
            return Color.secondary.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private var textColor: Color {
        isSelected ? .primary : .secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            // 탭 제목
            Text(tab.title)
                .font(.system(size: 12))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.middle)

            // 수정 표시 또는 닫기 버튼
            ZStack {
                // 수정됨 표시 (호버 아닐 때)
                if tab.isModified && !isHovering {
                    Circle()
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: 8, height: 8)
                } else {
                    // 닫기 버튼
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(isHovering ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16, height: 16)
                    .background(isHovering ? Color.secondary.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .opacity(isHovering || isSelected ? 1 : 0)
                }
            }
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minWidth: 100, maxWidth: 180, minHeight: 24)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            // 선택된 탭 상단 강조선
            VStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                }
                Spacer()
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let tabManager = TabManager()
    tabManager.addNewTab()
    tabManager.tabs[0].documentManager.windowTitle = "README.md"
    tabManager.tabs[0].documentManager.isModified = true
    tabManager.addNewTab()
    tabManager.tabs[1].documentManager.windowTitle = "ContentView.swift"

    return TabBarView(tabManager: tabManager) {
        tabManager.addNewTab()
    }
    .frame(width: 600)
}
