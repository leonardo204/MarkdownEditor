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

    // 창 크기 기억용 UserDefaults 키
    private static let rememberWindowSizeKey = "rememberWindowSize"
    private static let savedWindowWidthKey = "savedWindowWidth"
    private static let savedWindowHeightKey = "savedWindowHeight"

    private func setupWindow() {
        guard let window = window else { return }

        window.delegate = self
        window.title = documentManager.windowTitle
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)

        // 저장된 창 크기 복원 (설정이 켜져 있고 저장값이 있을 때만 크기만 적용, 위치는 center)
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.rememberWindowSizeKey) {
            let savedW = defaults.double(forKey: Self.savedWindowWidthKey)
            let savedH = defaults.double(forKey: Self.savedWindowHeightKey)
            if savedW >= 600, savedH >= 400 {
                var frame = window.frame
                frame.size = NSSize(width: savedW, height: savedH)
                window.setFrame(frame, display: false)
            }
        }

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

    func windowDidResize(_ notification: Notification) {
        // 설정이 켜져 있을 때만 현재 창 크기를 기록 (위치는 저장하지 않음)
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.rememberWindowSizeKey),
              let window = window else { return }
        let size = window.frame.size
        defaults.set(Double(size.width), forKey: Self.savedWindowWidthKey)
        defaults.set(Double(size.height), forKey: Self.savedWindowHeightKey)
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
