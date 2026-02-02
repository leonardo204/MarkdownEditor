import AppKit
import SwiftUI

// MARK: - 문서 윈도우 컨트롤러
// 단일 문서 윈도우 관리, NSWindowDelegate 구현, 네이티브 탭 지원
final class DocumentWindowController: NSWindowController, NSWindowDelegate {

    // 문서 관리자
    let documentManager: DocumentManager

    // SwiftUI 뷰 호스팅
    private var hostingView: NSHostingView<DocumentContentView>!

    // MARK: - 초기화

    convenience init(documentManager: DocumentManager) {
        // 프로그래매틱 윈도우 생성
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.init(window: window, documentManager: documentManager)
    }

    init(window: NSWindow, documentManager: DocumentManager) {
        self.documentManager = documentManager
        super.init(window: window)

        setupWindow()
        setupHostingView()
        configureNativeTabbing()

        // DocumentManager에 역참조 설정
        documentManager.windowController = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 윈도우 설정

    private func setupWindow() {
        guard let window = window else { return }

        window.delegate = self
        window.title = documentManager.windowTitle
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)

        // 화면 중앙에 배치
        window.center()

        // 윈도우 저장 복원 비활성화
        window.restorationClass = nil
        window.isRestorable = false
    }

    private func setupHostingView() {
        guard let window = window else { return }

        let contentView = DocumentContentView(documentManager: documentManager)
        hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView
    }

    private func configureNativeTabbing() {
        guard let window = window else { return }

        window.tabbingMode = .preferred
        window.tabbingIdentifier = "MarkdownEditorDocument"

        // 탭 바가 숨겨져 있으면 표시
        DispatchQueue.main.async {
            if let tabGroup = window.tabGroup, !tabGroup.isTabBarVisible {
                window.toggleTabBar(nil)
            }
        }
    }

    // MARK: - 윈도우 타이틀 업데이트

    func updateWindowTitle() {
        let title = documentManager.windowTitle
        let modified = documentManager.isModified ? " *" : ""
        window?.title = title + modified
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 수정사항 확인
        if documentManager.isModified {
            return documentManager.confirmSaveIfNeeded()
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        DebugLogger.shared.log("DocumentWindowController: windowWillClose '\(documentManager.windowTitle)'")
        // TabService가 NotificationCenter를 통해 자동으로 정리함
    }

    func windowDidBecomeKey(_ notification: Notification) {
        DebugLogger.shared.log("DocumentWindowController: windowDidBecomeKey '\(documentManager.windowTitle)'")
    }

    // MARK: - 네이티브 탭 지원

    // macOS가 Window > New Tab 메뉴에서 호출
    @objc override func newWindowForTab(_ sender: Any?) {
        DebugLogger.shared.log("DocumentWindowController: newWindowForTab called")

        guard let currentWindow = window else { return }

        // TabService를 통해 새 문서 생성
        if let newWindow = TabService.shared.newWindowForTab(orderFront: false) {
            currentWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        }
    }
}
