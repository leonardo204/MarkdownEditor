import AppKit
import SwiftUI

// MARK: - 탭 서비스
// 모든 문서 윈도우 컨트롤러의 생명주기 관리
final class TabService {
    static let shared = TabService()

    // MARK: - ManagedWindow 구조체
    struct ManagedWindow {
        let controller: DocumentWindowController
        let window: NSWindow
        let closeObserver: NSObjectProtocol
    }

    // 관리 중인 윈도우들 (강한 참조로 생명주기 보장)
    private(set) var managedWindows: [ManagedWindow] = []

    // Untitled 번호 추적
    private var untitledCounter: Int = 0

    private init() {}

    // MARK: - 윈도우 개수
    var managedWindowsCount: Int {
        return managedWindows.count
    }

    // MARK: - 새 문서 생성
    @discardableResult
    func createNewDocument() -> DocumentWindowController {
        let dm = DocumentManager()
        dm.windowTitle = generateNextUntitledTitle()

        let controller = DocumentWindowController(documentManager: dm)

        addManagedWindow(controller)

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)

        DebugLogger.shared.log("TabService: Created new document '\(dm.windowTitle)', total: \(managedWindows.count)")

        return controller
    }

    // MARK: - 파일 열기
    @discardableResult
    func openDocument(url: URL) -> DocumentWindowController? {
        // 이미 열린 파일인지 확인
        if let existingController = findController(for: url) {
            existingController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DebugLogger.shared.log("TabService: File already open, activating: \(url.lastPathComponent)")

            // 중복 파일 알림
            showDuplicateFileAlert(filename: url.lastPathComponent)
            return existingController
        }

        let dm = DocumentManager()
        dm.loadFile(from: url)

        let controller = DocumentWindowController(documentManager: dm)

        addManagedWindow(controller)

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)

        DebugLogger.shared.log("TabService: Opened file '\(url.lastPathComponent)', total: \(managedWindows.count)")

        return controller
    }

    // MARK: - 네이티브 탭 생성 (Window > New Tab 메뉴용)
    func newWindowForTab(orderFront: Bool) -> NSWindow? {
        let controller = createNewDocument()

        if !orderFront {
            controller.window?.orderOut(nil)
        }

        return controller.window
    }

    // MARK: - 탭으로 추가 (기존 윈도우에 탭으로 병합)
    func addAsTab(to existingWindow: NSWindow, controller: DocumentWindowController) {
        existingWindow.addTabbedWindow(controller.window!, ordered: .above)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - 윈도우 관리

    private func addManagedWindow(_ controller: DocumentWindowController) {
        guard let window = controller.window else { return }

        // 닫힘 알림 구독
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak controller] _ in
            guard let self = self, let controller = controller else { return }
            self.releaseController(controller)
        }

        managedWindows.append(ManagedWindow(
            controller: controller,
            window: window,
            closeObserver: observer
        ))
    }

    private func releaseController(_ controller: DocumentWindowController) {
        guard let index = managedWindows.firstIndex(where: { $0.controller === controller }) else { return }

        let managed = managedWindows[index]
        NotificationCenter.default.removeObserver(managed.closeObserver)
        managedWindows.remove(at: index)

        DebugLogger.shared.log("TabService: Released controller, remaining: \(managedWindows.count)")
    }

    // MARK: - 파일 찾기

    func findController(for url: URL) -> DocumentWindowController? {
        return managedWindows.first { managed in
            managed.controller.documentManager.currentFileURL?.standardizedFileURL == url.standardizedFileURL
        }?.controller
    }

    // MARK: - Untitled 번호 관리

    func generateNextUntitledTitle() -> String {
        // 사용 중인 Untitled 번호 수집
        var usedNumbers = Set<Int>()

        for managed in managedWindows {
            let title = managed.controller.documentManager.windowTitle
            if let number = parseUntitledNumber(from: title) {
                usedNumbers.insert(number)
            }
        }

        // 사용 가능한 가장 작은 번호 찾기
        var number = 1
        while usedNumbers.contains(number) {
            number += 1
        }

        return "Untitled \(number)"
    }

    private func parseUntitledNumber(from title: String) -> Int? {
        guard title.hasPrefix("Untitled") else { return nil }
        let suffix = title.dropFirst("Untitled".count).trimmingCharacters(in: .whitespaces)
        if suffix.isEmpty { return nil }
        return Int(suffix)
    }

    // MARK: - 앱 종료 시 저장 확인

    func confirmCloseAll() -> Bool {
        for managed in managedWindows {
            let dm = managed.controller.documentManager
            if dm.isModified {
                managed.window.makeKeyAndOrderFront(nil)

                if !dm.confirmSaveIfNeeded() {
                    return false  // 사용자가 취소함
                }
            }
        }
        return true
    }

    // MARK: - 중복 파일 알림

    private func showDuplicateFileAlert(filename: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "이미 열린 파일입니다"
            alert.informativeText = "\"\(filename)\" 파일이 이미 다른 창에서 열려 있습니다."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }
}
