import SwiftUI
import Combine

// MARK: - 탭 아이템
class TabItem: ObservableObject, Identifiable {
    let id = UUID()
    @Published var documentManager: DocumentManager

    init(documentManager: DocumentManager = DocumentManager()) {
        self.documentManager = documentManager
    }

    var title: String {
        documentManager.windowTitle
    }

    var isModified: Bool {
        documentManager.isModified
    }
}

// MARK: - 탭 관리자
class TabManager: ObservableObject {
    @Published var tabs: [TabItem] = []
    @Published var selectedTabIndex: Int = 0

    // 현재 선택된 탭
    var currentTab: TabItem? {
        guard selectedTabIndex >= 0 && selectedTabIndex < tabs.count else { return nil }
        return tabs[selectedTabIndex]
    }

    // 현재 DocumentManager
    var currentDocumentManager: DocumentManager? {
        currentTab?.documentManager
    }

    init() {
        // 초기 빈 탭 생성
        addNewTab()
    }

    // MARK: - 탭 작업

    // 새 탭 추가
    @discardableResult
    func addNewTab(documentManager: DocumentManager? = nil) -> TabItem {
        let dm: DocumentManager
        if let existingDM = documentManager {
            dm = existingDM
        } else {
            // 새 DocumentManager 생성 시 적절한 Untitled 번호 할당
            dm = DocumentManager()
            dm.windowTitle = WindowTabManagerRegistry.shared.generateNextUntitledTitle()
        }
        let tab = TabItem(documentManager: dm)
        tabs.append(tab)
        selectedTabIndex = tabs.count - 1
        DebugLogger.shared.log("TabManager: Added new tab '\(dm.windowTitle)', total: \(tabs.count)")
        return tab
    }

    // 탭 선택
    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTabIndex = index
        DebugLogger.shared.log("TabManager: Selected tab \(index)")
    }

    // 탭 선택 (ID로)
    func selectTab(id: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            selectTab(at: index)
        }
    }

    // 탭 닫기
    func closeTab(at index: Int) -> Bool {
        guard index >= 0 && index < tabs.count else { return false }

        let tab = tabs[index]

        // 수정된 문서가 있으면 저장 확인
        if tab.isModified {
            if !tab.documentManager.confirmSaveIfNeeded() {
                return false  // 사용자가 취소함
            }
        }

        tabs.remove(at: index)
        DebugLogger.shared.log("TabManager: Closed tab \(index), remaining: \(tabs.count)")

        // 탭이 없으면 창 닫기
        if tabs.isEmpty {
            DispatchQueue.main.async {
                NSApp.keyWindow?.close()
            }
            return true
        } else if selectedTabIndex >= tabs.count {
            selectedTabIndex = tabs.count - 1
        } else if selectedTabIndex > index {
            selectedTabIndex -= 1
        }

        return true
    }

    // 현재 탭 닫기
    func closeCurrentTab() -> Bool {
        return closeTab(at: selectedTabIndex)
    }

    // 탭 닫기 (ID로)
    func closeTab(id: UUID) -> Bool {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            return closeTab(at: index)
        }
        return false
    }

    // 탭 이동
    func moveTab(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0 && source < tabs.count,
              destination >= 0 && destination < tabs.count else { return }

        let tab = tabs.remove(at: source)
        tabs.insert(tab, at: destination)

        // 선택된 탭 인덱스 조정
        if selectedTabIndex == source {
            selectedTabIndex = destination
        } else if source < selectedTabIndex && destination >= selectedTabIndex {
            selectedTabIndex -= 1
        } else if source > selectedTabIndex && destination <= selectedTabIndex {
            selectedTabIndex += 1
        }

        DebugLogger.shared.log("TabManager: Moved tab from \(source) to \(destination)")
    }

    // 다음 탭 선택
    func selectNextTab() {
        if tabs.count > 1 {
            selectedTabIndex = (selectedTabIndex + 1) % tabs.count
        }
    }

    // 이전 탭 선택
    func selectPreviousTab() {
        if tabs.count > 1 {
            selectedTabIndex = (selectedTabIndex - 1 + tabs.count) % tabs.count
        }
    }

    // 특정 번호 탭 선택 (1-9)
    func selectTab(number: Int) {
        let index = number - 1
        if index >= 0 && index < tabs.count {
            selectedTabIndex = index
        }
    }

    // MARK: - 파일 작업

    // 파일을 새 탭에서 열기
    func openFileInNewTab(url: URL) {
        // 이미 열린 파일인지 확인
        if let existingIndex = tabs.firstIndex(where: {
            $0.documentManager.currentFileURL?.standardizedFileURL == url.standardizedFileURL
        }) {
            selectTab(at: existingIndex)
            DebugLogger.shared.log("TabManager: File already open, selecting tab \(existingIndex)")
            return
        }

        // 현재 탭이 비어있으면 현재 탭에서 열기
        if let current = currentTab,
           current.documentManager.currentFileURL == nil && current.documentManager.content.isEmpty {
            current.documentManager.loadFile(from: url)
            DebugLogger.shared.log("TabManager: Loaded file in current empty tab")
        } else {
            // 새 탭 생성
            let newTab = addNewTab()
            newTab.documentManager.loadFile(from: url)
            DebugLogger.shared.log("TabManager: Loaded file in new tab")
        }
    }

    // 모든 탭에 수정사항이 있는지 확인 (앱 종료 시)
    func hasAnyModifiedTabs() -> Bool {
        return tabs.contains { $0.isModified }
    }

    // 모든 탭 저장 확인 (앱 종료 시)
    func confirmSaveAllIfNeeded() -> Bool {
        for (index, tab) in tabs.enumerated() {
            if tab.isModified {
                selectTab(at: index)
                if !tab.documentManager.confirmSaveIfNeeded() {
                    return false
                }
            }
        }
        return true
    }
}
