import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 중앙 클릭 감지 (NSViewRepresentable)
struct MiddleClickDetector: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeNSView(context: Context) -> MiddleClickView {
        let view = MiddleClickView()
        view.onMiddleClick = onMiddleClick
        return view
    }

    func updateNSView(_ nsView: MiddleClickView, context: Context) {
        nsView.onMiddleClick = onMiddleClick
    }

    class MiddleClickView: NSView {
        var onMiddleClick: (() -> Void)?

        override func otherMouseDown(with event: NSEvent) {
            if event.buttonNumber == 2 {  // 중앙 버튼
                onMiddleClick?()
            } else {
                super.otherMouseDown(with: event)
            }
        }
    }
}

// MARK: - 탭 바 뷰
struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    let windowId: String
    let onNewTab: () -> Void

    // 드롭 대상 인덱스 (하이라이트용)
    @State private var dropTargetIndex: Int?

    // 탭 바 색상
    private let tabBarBackground = Color(NSColor.windowBackgroundColor).opacity(0.95)

    var body: some View {
        HStack(spacing: 0) {
            // 탭들 + 새 탭 버튼
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            tab: tab,
                            index: index,
                            windowId: windowId,
                            tabManager: tabManager,
                            isSelected: index == tabManager.selectedTabIndex,
                            isDropTarget: dropTargetIndex == index,
                            onSelect: {
                                DebugLogger.shared.log("TabBarView.onSelect: index=\(index), tab='\(tab.title)'")
                                tabManager.selectTab(at: index)
                            },
                            onClose: {
                                _ = tabManager.closeTab(at: index)
                            }
                        )
                    }

                    // 새 탭 버튼 (탭들 바로 옆)
                    Button(action: onNewTab) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }

            // 빈 영역 - 더블 클릭으로 새 탭 생성
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onNewTab()
                }
        }
        .frame(height: 32)
        .background(tabBarBackground)
        // 탭 바 전체에서 드롭 처리 (개별 TabItemView에서 처리하지 않음)
        .onDrop(of: [.tabItem], isTargeted: nil) { providers in
            handleDropProviders(providers, at: tabManager.tabs.count)
        }
    }

    // MARK: - 드롭 프로바이더 처리 (onDrop용)
    private func handleDropProviders(_ providers: [NSItemProvider], at targetIndex: Int) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.tabItem.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.tabItem.identifier) { data, error in
                    guard let data = data,
                          let transfer = try? JSONDecoder().decode(TabItemTransfer.self, from: data) else {
                        DebugLogger.shared.log("handleDropProviders: Failed to decode transfer data")
                        return
                    }
                    DispatchQueue.main.async {
                        _ = handleTabDrop(transfer, at: targetIndex)
                    }
                }
                return true
            }
        }
        return false
    }

    // MARK: - 탭 드롭 처리
    private func handleTabDrop(_ transfer: TabItemTransfer, at targetIndex: Int) -> Bool {
        if transfer.windowId == windowId {
            // 같은 윈도우 내 이동
            if let sourceIndex = tabManager.tabs.firstIndex(where: { $0.id == transfer.tabId }) {
                // 같은 위치면 무시
                if sourceIndex == targetIndex || sourceIndex == targetIndex - 1 {
                    return false
                }

                // 타겟 인덱스 조정 (소스가 타겟보다 앞에 있으면)
                let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
                tabManager.moveTab(from: sourceIndex, to: adjustedTarget)
                return true
            }
        } else {
            // 다른 윈도우에서 온 탭
            return handleCrossWindowTabDrop(transfer, at: targetIndex)
        }
        return false
    }

    // MARK: - 윈도우 간 탭 이동
    // NOTE: 네이티브 윈도우 탭 사용으로 이 기능은 비활성화됨
    private func handleCrossWindowTabDrop(_ transfer: TabItemTransfer, at targetIndex: Int) -> Bool {
        // 네이티브 탭을 사용하므로 커스텀 크로스 윈도우 탭 이동은 비활성화
        DebugLogger.shared.log("handleCrossWindowTabDrop: Disabled (using native window tabs)")
        return false
    }

    // 윈도우 ID로 윈도우 찾기
    private func findWindow(withId id: String) -> NSWindow? {
        for window in NSApp.windows {
            if window.identifier?.rawValue == id {
                return window
            }
        }
        return nil
    }
}

// MARK: - 개별 탭 아이템 뷰
struct TabItemView: View {
    @ObservedObject var tab: TabItem
    let index: Int
    let windowId: String
    let tabManager: TabManager
    let isSelected: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false

    // 색상
    private var backgroundColor: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.3)
        } else if isSelected {
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
        // 드롭 타겟 표시 (왼쪽 경계선)
        .overlay(
            HStack {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor)
                        .frame(width: 2)
                }
                Spacer()
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            DebugLogger.shared.log("TabItemView: Tap detected on '\(tab.title)' at index \(index)")
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        // 중앙 클릭으로 탭 닫기
        .overlay(
            MiddleClickDetector(onMiddleClick: onClose)
        )
        // 드래그 가능 (Transferable 사용)
        // NOTE: 네이티브 윈도우 탭 사용으로 탭 분리 기능은 macOS가 처리
        .draggable(TabItemTransfer(tabId: tab.id, windowId: windowId)) {
            TabDragPreview(title: tab.title, isModified: tab.isModified)
        }
        .opacity(isDragging ? 0.5 : 1.0)
    }
}

// MARK: - 탭 드래그 미리보기
struct TabDragPreview: View {
    let title: String
    let isModified: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)

            if isModified {
                Circle()
                    .fill(Color.primary.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
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

    return TabBarView(tabManager: tabManager, windowId: "preview-window") {
        tabManager.addNewTab()
    }
    .frame(width: 600)
}
